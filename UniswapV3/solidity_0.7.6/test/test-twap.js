const UniswapV3Twap = artifacts.require("UniswapV3Twap");

const FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984"
// USDC
const TOKEN_0 = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
const DECIMALS_0 = 6n
// WETH
const TOKEN_1 = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
const DECIMALS_1 = 18n
// 0.3%
const FEE = 3000
// Pair
// 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8

contract("UniswapV3Twap", () => {
  it("get price", async () => {
    const twap = await UniswapV3Twap.new(FACTORY, TOKEN_0, TOKEN_1, FEE)
    //await twap.deployed()

    const price = await twap.estimateAmountOut(TOKEN_1, 10n ** DECIMALS_1, 10)

    console.log(`price: ${price}`)
    
            // Result of running this test on September 25th
    // >>> 1306286819 / 10 ** 6
    // 1306.286819
  })
})