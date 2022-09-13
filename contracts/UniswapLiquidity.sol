pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";


contract UniswapLiquidity {
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

    // Return the remaining tokens to the provider
    uint remainingTokenA = _amountA - amountA;
    uint remainingTokenB = _amountB - amountB;

    IERC20(_tokenA).transferFrom(address(this), msg.sender, remainingTokenA);
    IERC20(_tokenB).transferFrom(address(this), msg.sender, remainingTokenB);
    

    address pair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(_tokenA, _tokenB);
    liquidityOwnership[msg.sender] = liquidityOwnership[msg.sender] + liquidity;
    uint contractOriginalLiquidity = IERC20(pair).balanceOf(address(this));

    emit Log("amountA", amountA);
    emit Log("amountB", amountB);
    emit Log("liquidity", liquidity);
    emit Log("Total liquidity held by the provider", liquidityOwnership[msg.sender]);
    emit Log("Total liquidity provider tokens held in this contract: ", contractOriginalLiquidity);

    uint totalTokenA = IERC20(_tokenA).balanceOf(address(this));
    emit Log("Total tokenA held in this contract: ", totalTokenA);

    uint totalTokenAInPool = IERC20(_tokenA).balanceOf(pair);
    emit Log("Total tokenA held in the pool contract: ", totalTokenAInPool);

  }

  function removeLiquidity(address _tokenA, address _tokenB) external {
    uint liquidity = liquidityOwnership[msg.sender]; // Provider's total liquidity
    require(liquidity > 0, "Error, this address does not have provider any liquidity");

    address pair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(_tokenA, _tokenB);
    uint contractOriginalLiquidity = IERC20(pair).balanceOf(address(this));

    // Set provider's liquidity to 0
    liquidityOwnership[msg.sender] = 0;
    IERC20(pair).approve(UNISWAP_ROUTER, liquidity);
    // Remove provider's liquidity from this contract and send tokens A & B to te provider's address
    (uint amountA, uint amountB) = IUniswapV2Router02(UNISWAP_ROUTER).removeLiquidity(_tokenA,_tokenB,liquidity,1,1,msg.sender,block.timestamp);

    uint contractRemainingLiquidity = IERC20(pair).balanceOf(address(this));
    emit Log("Token A Returned a total of:" , amountA);
    emit Log("Token B Returned a total of:" , amountB);
    emit Log("Original Liquidity in this contract: ", contractOriginalLiquidity);
    emit Log("Remaining Liquidity in this contract: ", contractRemainingLiquidity);

    uint totalTokenA = IERC20(_tokenA).balanceOf(address(this));
    emit Log("Total tokenA held in this contract: ", totalTokenA);

  }



}