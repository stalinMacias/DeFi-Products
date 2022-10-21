// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./interfaces/compound.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// <---> The next operations will be performed using the contract:                    CompoundBorrower
// supply tokens to the compound protocol
// enter the market using the cTokens that the supplier received after supplying its tokens to the protocol
// borrow max amount determiend by the total liquidity that was credited after entering the market
// wait few blocks and let that : -------> borrowed balance > supplied balance * col factor     <----> When this happens, the borrow becomes subject to be liquidated!

// <--> The last operation (The liquidation) will be executed using the contract:     CompoundLiquidator
// liquidate 

contract CompoundBorrower {
  Comptroller public comptroller =
    Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

  PriceFeed public priceFeed = PriceFeed(0x922018674c12a7F0D394ebEEf9B58F186CdE13c1);

  IERC20 public tokenSupply;
  CErc20 public cTokenSupply;
  IERC20 public tokenBorrow;
  CErc20 public cTokenBorrow;

  event Log(string message, uint val);

  constructor(
    address _tokenSupply,
    address _cTokenSupply,
    address _tokenBorrow,
    address _cTokenBorrow
  ) {
    tokenSupply = IERC20(_tokenSupply);
    cTokenSupply = CErc20(_cTokenSupply);

    tokenBorrow = IERC20(_tokenBorrow);
    cTokenBorrow = CErc20(_cTokenBorrow);
  }

  function supply(uint _amount) external {
    tokenSupply.transferFrom(msg.sender, address(this), _amount);
    tokenSupply.approve(address(cTokenSupply), _amount);
    require(cTokenSupply.mint(_amount) == 0, "mint failed");
  }

  // not view function
  function getSupplyBalance() external returns (uint) {
    return cTokenSupply.balanceOfUnderlying(address(this));
  }

  function getCollateralFactor() external view returns (uint) {
    (, uint colFactor, ) = comptroller.markets(address(cTokenSupply));
    return colFactor; // divide by 1e18 to get in %
  }

  function getAccountLiquidity() external view returns (uint liquidity, uint shortfall) {
    // liquidity and shortfall in USD scaled up by 1e18
    (uint error, uint _liquidity, uint _shortfall) = comptroller.getAccountLiquidity(
      address(this)
    );
    require(error == 0, "error");
    return (_liquidity, _shortfall);
  }

  function getPriceFeed(address _cToken) external view returns (uint) {
    // scaled up by 1e18
    return priceFeed.getUnderlyingPrice(_cToken);
  }

  function enterMarket() external {
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cTokenSupply);
    uint[] memory errors = comptroller.enterMarkets(cTokens);
    require(errors[0] == 0, "Comptroller.enterMarkets failed.");
  }

  function borrow(uint _amount) external {
    require(cTokenBorrow.borrow(_amount) == 0, "borrow failed");
  }

  // not view function
  function getBorrowBalance() public returns (uint) {
    return cTokenBorrow.borrowBalanceCurrent(address(this));
  }
}

contract CompoundLiquidator {
  Comptroller public comptroller = Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
  
  IERC20 public tokenBorrow;
  CErc20 public cTokenBorrow;
  
  constructor(address _tokenBorrow, address _cTokenBorrow) {
    tokenBorrow = IERC20(_tokenBorrow);
    cTokenBorrow = CErc20(_cTokenBorrow);
  }

  /**
   * @dev close factor is the maximum percentage of the borrowed token that can be repaid
   * @return value comes from calling the closeFactorMantissa() function using the comptroller state variable
   */
  function getCloseFactor() external view returns (uint) {
    return comptroller.closeFactorMantissa();
  }

  /**
   * @dev Liquidation incentive is the amount of collateral that is given to the liquidator
   * @return an uint that represents the amount of collateral that is given to the liquidator
   */
  function getLiquidationIncentive() external view returns (uint) {
    return comptroller.liquidationIncentiveMantissa();
  }

  /**
   * @dev get the exact number of collateral that will be liquidated
   * @param _cTokenBorrowed -> The address of the cToken contract that was borrowed
   * @param _cTokenCollateral -> The address of the cToken contract of the collateral that will be given to the liquidator for liquidating the borrow
   * @param _actualRepayAmount -> The amount that will be paid to liquidate the borrow
   */
  function getAmountToBeLiquidated(
    address _cTokenBorrowed,
    address _cTokenCollateral,
    uint _actualRepayAmount
  ) external view returns (uint) {
    /*
     * Get the exchange rate and calculate the number of collateral tokens to seize:
     *  seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
     *  seizeTokens = seizeAmount / exchangeRate
     *   = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
     */
    (uint result, uint cTokenCollateralAmount) = comptroller.liquidateCalculateSeizeTokens(_cTokenBorrowed,_cTokenCollateral,_actualRepayAmount);
    require(result == 0, "Error while calling the liquidateCalculateSeizeTokens() function");
    return cTokenCollateralAmount;
  }

  /**
   * @dev Liquidate a borrow that is undercollateralized
   * @param _borrower -> The address of the borrower that is holding an undercollateralized borrow
   * @param _repayAmount -> The amount that will be paid to liquidate the borrow
   * @param _cTokenCollateral -> The address of the collateral cToken that will be given to the liquidator in exchange for liquidating the borrow
   */
  function liquidate(address _borrower, uint _repayAmount, address _cTokenCollateral) external {
    tokenBorrow.transferFrom(msg.sender, address(this), _repayAmount);
    tokenBorrow.approve(address(cTokenBorrow), _repayAmount);
    require(cTokenBorrow.liquidateBorrow(_borrower, _repayAmount, _cTokenCollateral) == 0, "Error while liquidating the borrow");
  }

  // get amount liquidated
  // not view function
  function getSupplyBalance(address _cTokenCollateral) external returns (uint) {
    return CErc20(_cTokenCollateral).balanceOfUnderlying(address(this));
  }

}