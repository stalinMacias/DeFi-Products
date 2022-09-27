// SPX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";

// CSAMM stanfs for Constant Sum Auto Market Maker
// CSAMM are not really used in DeFi real products, but CSAMM are useful for education purposes

contract CSAMM {

  IERC20 public immutable token0;
  IERC20 public immutable token1;

  uint public reserve0; // amount of tokens0 locked on this in contract
  uint public reserve1; // amount of tokens1 locked on this in contract

  uint public totalSupply;  // totalShares minted
  mapping(address => uint) public balanceOf;  // shares owned by each provider

  constructor(address _token0, address _token1) {
    token0 = IERC20(_token0);
    token1 = IERC20(_token1);
  }

  function _mint(address _to, uint _amount) private {
    balanceOf[msg.sender] += _amount;
    totalSupply += _amount;
  }

  function _burn(address _from, uint _amount) private {
    balanceOf[msg.sender] -= _amount;
    totalSupply -= _amount;
  }

  function _update(uint _newReserve0, uint _newReserver1) internal {
    reserve0 = _newReserve0;
    reserve1 = _newReserver1;
  }

  function swap(address _tokenIn, uint _amountIn) external returns (uint amountOut) {
    require(_tokenIn == address(token0) || _tokenIn == address(token1) , "_tokenIn is not a valid token for this CSAMM");
    
    // transfer token in
    uint amountIn;
    bool isToken0 = (_tokenIn == address(token0));
    (IERC20 tokenIn, IERC20 tokenOut, uint reserveIn, uint reserveOut) = isToken0 
      ? (token0, token1, reserve0, reserve1) 
      : (token1, token0, reserve1, reserve0) ;

    tokenIn.transferFrom(msg.sender, address(this), _amountIn);
    amountIn = tokenIn.balanceOf(address(this)) - reserveIn;
    
    // calculate amount of tokens out (including fees)
    // 3% fee = 0.3%
    amountOut = (amountIn / 997) * 1000;

    // update reserve0 and reserve1 state variables
    (uint res0, uint res1) = (isToken0)
      ? (reserveIn + _amountIn, reserveOut - amountOut)
      : (reserveOut - amountOut, reserveIn + _amountIn );

    _update(res0, res1);

    // transfer token out
    tokenOut.transfer(msg.sender, amountOut);

  }






}