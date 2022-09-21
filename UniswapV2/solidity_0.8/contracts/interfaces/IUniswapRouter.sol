// This is an implementation of my own - It contains only the methods that'll be used through this practices from the original IUniswapVXRouter.sol interfaces 

pragma solidity ^0.8.0;

interface IUniswapRouter {
  
  function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  ) external returns (uint[] memory amounts);

}