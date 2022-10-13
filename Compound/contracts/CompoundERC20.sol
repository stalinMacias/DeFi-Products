// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/compund.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CompountERC20 {
  IERC20 public token;
  CErc20 public cToken;

  constructor(address _token, address _cToken) {
    token = IERC20(_token);
    cToken = CErc20(_cToken);
  }

  function supply(uint _amount) external{
    token.transferFrom(msg.sender,address(this),_amount); //Transfering the tokens from the caller address into this contract
    token.approve(address(cToken),_amount);
    require(cToken.mint(_amount) == 0, "An error occured while supplying the tokens to the Compound protocol");
  }

  function getCTokenBalance() external view returns (uint) {
    return cToken.balanceOf(address(this));
  }

  function getInto() external returns(uint exchangeRate, uint supplyRate) {
    exchangeRate = cToken.exchangeRateCurrent();
    supplyRate = cToken.supplyRatePerBlock();
  }

  function balanceOfUnderliying() returns (uint) {
    return cToken.balanceOfUnderlying(address(token));
  }

  function redeem(uint _cTokenAmount) external {
    require(cToken.redeem(_cTokenAmount) == 0, "An error occured while redeeming the base tokens from te Compound protocol");
  }

}