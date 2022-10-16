// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/compund.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CompoundERC20 {
  IERC20 public token;
  CErc20 public cToken;

  Comptroller public comptroller = Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B); 
  PriceFeed public priceFeed = PriceFeed(0x922018674c12a7F0D394ebEEf9B58F186CdE13c1);

  /**
  * @dev constructor() This constructor initializes the variables token & cToken with their corresponding addresses, so they can be used without the need to specify the address on each call!
  */
  constructor(address _token, address _cToken) {
    token = IERC20(_token);
    cToken = CErc20(_cToken);
  }

  /**
  * @dev supply() function is used to lend tokens to the protocol & in exchange the lender will receive cTokens that will be accruing interests as the times goes
  */
  function supply(uint _amount) external{
    token.transferFrom(msg.sender,address(this),_amount); //Transfering the tokens from the caller address into this contract
    token.approve(address(cToken),_amount);
    require(cToken.mint(_amount) == 0, "An error occured while supplying the tokens to the Compound protocol");
  }

  function getCTokenBalance() external view returns (uint) {
    return cToken.balanceOf(address(this));
  }

  function getInfo() external returns(uint exchangeRate, uint supplyRate) {
    exchangeRate = cToken.exchangeRateCurrent();
    supplyRate = cToken.supplyRatePerBlock();
  }

  /**
  * @dev balanceOfUnderlying() function is used to check the total balance of the underlying token from a cToken that an address holds
  */
  function balanceOfUnderlying() external returns (uint) {
    return cToken.balanceOfUnderlying(address(this));
  }

  /**
  * @dev redeem() function is used to exchange cTokens for the underlying tokens that were lended to the protocol + all the interests that were generated
  */
  function redeem(uint _cTokenAmount) external {
    require(cToken.redeem(_cTokenAmount) == 0, "An error occured while redeeming the base tokens from te Compound protocol");
  }

  // borrow and repay //

  function getCollateralFactor() external view returns (uint) {
    (bool isListed, uint colFactor, bool isComped) = comptroller.markets(address(cToken));
    return colFactor; // divide by 1e18 to get in %
  }

  // account liquidity - calculate how much can I borrow?
  // sum of (supplied balance of market entered * col factor) - borrowed
  function getAccountLiquidity() external view returns (uint liquidity, uint shortfall) {
    // liquidity and shortfall in USD scaled up by 1e18
    (uint error, uint _liquidity, uint _shortfall) = comptroller.getAccountLiquidity(address(this));
    require(error == 0, "Error while getting the account liquidity");
    // normal circumstance - liquidity > 0 and shortfall == 0
    // liquidity > 0 means account can borrow up to `liquidity`
    // shortfall > 0 is subject to liquidation, you borrowed over limit
    return (_liquidity, _shortfall);
  }

  function getPriceFeed(address _cToken) external view returns (uint) {
    return priceFeed.getUnderlyingPrice(address(_cToken));
  }

  // enter market and borrow a 50% of the max borr0w amount
  function borrow(address _cTokenToBorrow, uint _decimals) external {
    // enter the supply market so you can borrow another type of asset
    //Enter the market --->  means using the cTokens that were given to you when you lend out a base token to the compound protocol and add those cTokens as your entrance to the market
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    uint[] memory errors = comptroller.enterMarkets(cTokens);
    require(errors[0] == 0, "Comptroller.enterMarkets failed.");

    // Check liquidity after entering the market
    // Once you entered the market by sending your cToken(s) to the comptroller, your account's liquidity was increased in terms of usd value.
    (uint error, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(address(this));
    // Validate that the below criterias are met, otherwise, the account is not elegible to ask for a borrow
    // normal circumstance - liquidity > 0 and shortfall == 0
    // liquidity > 0 means account can borrow up to `liquidity`
    // shortfall > 0 is subject to liquidation, you borrowed over limit
    require(error == 0, "error");
    require(shortfall == 0, "shortfall > 0");
    require(liquidity > 0, "liquidity = 0");

    // Calculate max borrow for the _cTokenToBorrow
    uint price = priceFeed.getUnderlyingPrice(_cTokenToBorrow);

    // liquidity - USD scaled up by 1e18
    // price - USD scaled up by 1e18
    // decimals - decimals of token to borrow
    uint maxBorrow = (liquidity * (10**_decimals)) / price;
    require(maxBorrow > 0, "Error, max borrow = 0");

    //Calculate the 50% of the max borrow
    uint amount = (maxBorrow * 50) / 100;
    // borrow 50% of max borrow
    require(CErc20(_cTokenToBorrow).borrow(amount) == 0, "Error while borrowing the 50% of the max borrow amount");

  }

  /**
  * @dev getBorrowedBalance() get the number of borrowed tokens plus all the interests that the original borrowed ammount has accumulated
  * @return uint that represents the number of borrowed tokens plus all the interests that the original borrowed ammount has accumulated
  */
  function getBorrowedBalance(address _cTokenBorrowed) public returns (uint) {
    return CErc20(_cTokenBorrowed).borrowBalanceCurrent(address(this));
  }

  // borrow rate
  function getBorrowRatePerBlock(address _cTokenBorrowed) external view returns (uint) {
    // scaled up by 1e18
    return CErc20(_cTokenBorrowed).borrowRatePerBlock();
  }

  // repay borrow
  function repay(
    address _tokenBorrowed,
    address _cTokenBorrowed,
    uint _amount
  ) external {
    // Is a requirement that the contract that will call the repayBorrow() function from the cTokenBorrowed contract has enough cTokens in its balance!
    IERC20(_tokenBorrowed).approve(_cTokenBorrowed,_amount);
    // _amount = 2 ** 256 - 1 means repay all
    require(CErc20(_cTokenBorrowed).repayBorrow(_amount) == 0, "Error while calling the repayBorrow function");
  }

}