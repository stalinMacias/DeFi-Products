// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

/* Long ETH
1. supply ETH
2. borrow stable coin (DAI, USDC)
3. buy ETH on Uniswap
when the price of ETH goes up...
4. sell ETH on Uniswap
5. repay borrowed stable coin
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/compound.sol";
import "./interfaces/Uniswap.sol";

contract CompoundLong {
  CEth public cEth;
  CErc20 public cTokenBorrow;
  IERC20 public tokenBorrow;
  uint public decimals;

  Comptroller public comptroller =
    Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

  PriceFeed public priceFeed = PriceFeed(0x922018674c12a7F0D394ebEEf9B58F186CdE13c1);

  IUniswapV2Router private constant UNI =
    IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  IERC20 private constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  /**
   * @dev Right after initializing the state variables the constructor will enter the market in the compound protocol the cETH token
   */
  constructor(
    address _cEth,
    address _cTokenBorrow,
    address _tokenBorrow,
    uint _decimals
  ) {
    cEth = CEth(_cEth);
    cTokenBorrow = CErc20(_cTokenBorrow);
    tokenBorrow = IERC20(_tokenBorrow);
    decimals = _decimals;

    // enter market to enable borrow using CETH Tokens
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cEth);
    uint[] memory errors = comptroller.enterMarkets(cTokens);
    require(errors[0] == 0, "Comptroller.enterMarkets failed.");
  }

  /**
   * @dev receive() function is called when sending ethers to the contract and msg.data is empty
   * when msg.value > 0 && msg.data == empty!
   */
  receive() external payable {}

  /**
   * @dev supply() function mints new cETH tokens into this exchange, it sends the Ethers that are passed when calling this function into the cEth contract!
   */
  function supply() external payable {
    cEth.mint{value: msg.value}();
  }

  /**
   * @dev Determine the maximum amount in usd value that this contract is allowed to borrow from the compound protocol
   */
  function getMaxBorrow() external view returns (uint) {
    (uint error, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(
      address(this)
    );

    require(error == 0, "error");
    require(shortfall == 0, "shortfall > 0");
    require(liquidity > 0, "liquidity = 0");

    uint price = priceFeed.getUnderlyingPrice(address(cTokenBorrow));
    uint maxBorrow = (liquidity * (10**decimals)) / price;

    return maxBorrow;
  }

  /**
   * @dev long() functions asks the borrow from the compound protocol and then uses Uniswap to buy the ETHs that will be used as the long position!
   */
  function long(uint _borrowAmount) external {
    // borrow from the compound protocol
    require(cTokenBorrow.borrow(_borrowAmount) == 0, "borrow failed");

    // buy ETH using Uniswap
    uint bal = tokenBorrow.balanceOf(address(this));
    tokenBorrow.approve(address(UNI), bal);

    address[] memory path = new address[](2);
    path[0] = address(tokenBorrow);
    path[1] = address(WETH);
    UNI.swapExactTokensForETH(bal, 1, path, address(this), block.timestamp);
  }

  /**
   * @dev repay() function sells the ETH that were bought at the beginning of the long position and then repays the borrow that was made in the compound protocol
   * The user is left with: original supplied ETH + supplied interest + profit (in token borrow) 
   */
  function repay() external {
    // sell ETH using Uniswap
    address[] memory path = new address[](2);
    path[0] = address(WETH);
    path[1] = address(tokenBorrow);
    UNI.swapExactETHForTokens{value: address(this).balance}(
      1,
      path,
      address(this),
      block.timestamp
    );
    // repay borrow in the Compound Protocol
    uint borrowed = cTokenBorrow.borrowBalanceCurrent(address(this));
    tokenBorrow.approve(address(cTokenBorrow), borrowed);
    require(cTokenBorrow.repayBorrow(borrowed) == 0, "repay failed");

    uint supplied = cEth.balanceOfUnderlying(address(this));
    require(cEth.redeemUnderlying(supplied) == 0, "redeem failed");

    // The user is left with: original supplied ETH + supplied interest + profit (in token borrow)
  }

  // not view function - getSuppliedBalance() returns the total amount of value a lender has in the compound protocol - Original supplied amount + accrued interests
  function getSuppliedBalance() external returns (uint) {
    return cEth.balanceOfUnderlying(address(this));
  }

  // not view function
  /**
   * @dev getBorrowBalance() returns the total amount of "debt" that the borrower has for a borrow - Original borrowed amount + accrued interests
   */
  function getBorrowBalance() external returns (uint) {
    return cTokenBorrow.borrowBalanceCurrent(address(this));
  }

  function getAccountLiquidity()
    external
    view
    returns (uint liquidity, uint shortfall)
  {
    // liquidity and shortfall in USD scaled up by 1e18
    (uint error, uint _liquidity, uint _shortfall) = comptroller.getAccountLiquidity(
      address(this)
    );
    require(error == 0, "error");
    return (_liquidity, _shortfall);
  }

}