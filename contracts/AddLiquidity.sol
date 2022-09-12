pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";


contract AddLiquidity {
  address private constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
  address private constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  mapping(address => uint) liquidityOwnership;

  event Log(string message, uint value);
  
  function addLiquidity(address _tokenA, address _tokenB, uint _amountA, uint _amountB) external {
    IERC20(_tokenA).transferFrom(msg.sender, address(this), _amountA);
    IERC20(_tokenB).transferFrom(msg.sender, address(this), _amountB);

    IERC20(_tokenA).approve(UNISWAP_ROUTER, _amountA);
    IERC20(_tokenB).approve(UNISWAP_ROUTER, _amountB);

    (uint amountA, uint amountB, uint liquidity) = 
    IUniswapV2Router02(UNISWAP_ROUTER).addLiquidity(
      _tokenA,
      _tokenB,
      _amountA,
      _amountB,
      1,
      1,
      address(this),
      block.timestamp
    );

    liquidityOwnership[msg.sender] = liquidityOwnership[msg.sender] + liquidity;

    emit Log("amountA", amountA);
    emit Log("amountB", amountB);
    emit Log("liquidity", liquidity);
    emit Log("Total liquidity held by the provider", liquidityOwnership[msg.sender]);
  }

  function removeLiquidity(address _tokenA, address _tokenB) external {
    address pair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(_tokenA, _tokenB);
    
    uint contractOriginalLiquidity = IERC20(pair).balanceOf(address(this));

    uint liquidity = liquidityOwnership[msg.sender]; // Provider's total liquidity
    liquidityOwnership[msg.sender] = 0;
    IERC20(pair).approve(UNISWAP_ROUTER, liquidity);
    (uint amountA, uint amountB) = IUniswapV2Router02(UNISWAP_ROUTER).removeLiquidity(_tokenA,_tokenB,liquidity,1,1,msg.sender,block.timestamp);

    uint contractRemainingLiquidity = IERC20(pair).balanceOf(address(this));
    emit Log("Token A Returned a total of:" , amountA);
    emit Log("Token B Returned a total of:" , amountB);
    emit Log("Original Liquidity in this contract: ", contractOriginalLiquidity);
    emit Log("Remaining Liquidity in this contract: ", contractRemainingLiquidity);

  }



}