const { time } = require("@openzeppelin/test-helpers")
const assert = require("assert")
const BN = require("bn.js")
const { sendEther, pow } = require("./util")
const { DAI, DAI_WHALE, CDAI, WBTC, WBTC_WHALE, CWBTC } = require("./config")
const { web3 } = require("@openzeppelin/test-helpers/src/setup")

const IERC20 = artifacts.require("IERC20")
const CErc20 = artifacts.require("CErc20")
const CompoundBorrower = artifacts.require("CompoundBorrower")
const CompoundLiquidator = artifacts.require("CompoundLiquidator")

contract("CompoundBorrower", (accounts) => {
  const SUPPLY_WHALE = WBTC_WHALE
  const TOKEN_SUPPLY = WBTC
  const C_TOKEN_SUPPLY = CWBTC
  const TOKEN_BORROW = DAI
  const C_TOKEN_BORROW = CDAI
  const LIQUIDATOR = DAI_WHALE

  const SUPPLY_DECIMALS = 8
  const SUPPLY_AMOUNT = pow(10, SUPPLY_DECIMALS).mul(new BN(1))
  const BORROW_DECIMALS = 18

  let testCompound
  let tokenSupply
  let cTokenSupply
  let tokenBorrow
  let cTokenBorrow
  let liquidator
  beforeEach(async () => {
    await sendEther(web3, accounts[0], SUPPLY_WHALE, 1)
    await sendEther(web3, accounts[0], LIQUIDATOR, 5)

    testCompound = await CompoundBorrower.new(TOKEN_SUPPLY, C_TOKEN_SUPPLY, TOKEN_BORROW, C_TOKEN_BORROW)
    tokenSupply = await IERC20.at(TOKEN_SUPPLY)
    cTokenSupply = await CErc20.at(C_TOKEN_SUPPLY)
    tokenBorrow = await IERC20.at(TOKEN_BORROW)
    cTokenBorrow = await CErc20.at(C_TOKEN_BORROW)
    liquidator = await CompoundLiquidator.new(TOKEN_BORROW, C_TOKEN_BORROW)

    const supplyBal = await tokenSupply.balanceOf(SUPPLY_WHALE)
    console.log(`suuply whale balance: ${supplyBal.div(pow(10, SUPPLY_DECIMALS))}`)
    assert(supplyBal.gte(SUPPLY_AMOUNT), "bal < supply")
  })

  const snapshot = async (testCompound, liquidator) => {
    const supplied = await testCompound.getSupplyBalance.call()
    const borrowed = await testCompound.getBorrowBalance.call()
    const colFactor = await testCompound.getCollateralFactor()
    const { liquidity, shortfall } = await testCompound.getAccountLiquidity()
    const price = await testCompound.getPriceFeed(C_TOKEN_BORROW)
    const closeFactor = await liquidator.getCloseFactor()
    const incentive = await liquidator.getLiquidationIncentive()
    const liquidated = await liquidator.getSupplyBalance.call(C_TOKEN_SUPPLY)

    return {
      colFactor: colFactor.div(pow(10, 18 - 2)),
      supplied: supplied.div(pow(10, SUPPLY_DECIMALS - 2)) / 100,
      borrowed: borrowed.div(pow(10, BORROW_DECIMALS - 2)) / 100,
      price: price.div(pow(10, 18 - 2)) / 100,
      liquidity: liquidity.div(pow(10, 14)) / 10000,
      shortfall: shortfall.div(pow(10, 14)) / 10000,
      closeFactor: closeFactor.div(pow(10, 18 - 2)),
      incentive: incentive.div(pow(10, 18 - 2)) / 100,
      liquidated: liquidated.div(pow(10, SUPPLY_DECIMALS - 4)) / 10000,
    }
  }

  it("should liquidate", async () => {
    // used for debugging
    let tx
    let snap

    // supply
    await tokenSupply.approve(testCompound.address, SUPPLY_AMOUNT, { from: SUPPLY_WHALE })
    tx = await testCompound.supply(SUPPLY_AMOUNT, {
      from: SUPPLY_WHALE,
    })

    snap = await snapshot(testCompound, liquidator)
    console.log(`--- supplied ---`)
    console.log(`col factor: ${snap.colFactor} %`)
    console.log(`supplied: ${snap.supplied}`)

    // enter market
    tx = await testCompound.enterMarket({ from: accounts[0] })

    // borrow
    const { liquidity } = await testCompound.getAccountLiquidity()
    const price = await testCompound.getPriceFeed(C_TOKEN_BORROW)
    const maxBorrow = liquidity.mul(pow(10, BORROW_DECIMALS)).div(price)
    // NOTE: tweak borrow amount if borrow fails
    const borrowAmount = maxBorrow.mul(new BN(10008)).div(new BN(10000))

    console.log(`--- entered market ---`)
    console.log(`liquidity: $ ${liquidity.div(pow(10, 18))}`)
    console.log(`price: $ ${price.div(pow(10, 18))}`)
    console.log(`max borrow: ${maxBorrow.div(pow(10, 18))}`)
    console.log(`borrow amount: ${borrowAmount.div(pow(10, 18))}`)

    tx = await testCompound.borrow(borrowAmount, { from: accounts[0] })

    snap = await snapshot(testCompound, liquidator)
    console.log(`--- borrowed ---`)
    console.log(`liquidity: $ ${snap.liquidity}`)
    console.log(`borrowed: ${snap.borrowed}`)

    // accrue interest on borrow
    const block = await web3.eth.getBlockNumber()
    // NOTE: tweak this to increase borrowed amount
    await time.advanceBlockTo(block + 10000)

    // send any tx to Compound to update liquidity and shortfall
    await testCompound.getBorrowBalance()

    snap = await snapshot(testCompound, liquidator)
    console.log(`--- after some blocks... ---`)
    console.log(`liquidity: $ ${snap.liquidity}`)
    console.log(`shortfall: $ ${snap.shortfall}`)
    console.log(`borrowed: ${snap.borrowed}`)

    // liquidate
    const closeFactor = await liquidator.getCloseFactor()
    const repayAmount = (await testCompound.getBorrowBalance.call()).mul(closeFactor).div(pow(10, 18))

    const liqBal = await tokenBorrow.balanceOf(LIQUIDATOR)
    console.log(`liquidator balance: ${liqBal.div(pow(10, BORROW_DECIMALS))}`)
    assert(liqBal.gte(repayAmount), "bal < repay")

    const amountToBeLiquidated = await liquidator.getAmountToBeLiquidated(C_TOKEN_BORROW, C_TOKEN_SUPPLY, repayAmount)
    console.log(
      `amount to be liquidated (cToken collateral):  ${amountToBeLiquidated.div(pow(10, SUPPLY_DECIMALS - 2)) / 100}`
    )

    await tokenBorrow.approve(liquidator.address, repayAmount, { from: LIQUIDATOR })

    console.log("Ether available in the LIQUIDATOR account before calling the liquidator() function: ", await web3.eth.getBalance(LIQUIDATOR));
    try {
      await liquidator.liquidate(testCompound.address, repayAmount, C_TOKEN_SUPPLY, { from: LIQUIDATOR })
      // When the receipt is received indicated that the transaction has been completed
      .once('receipt', function(receipt){
        console.log("Transaction completed"); 
        //console.log("receipt", receipt) 
      })
      .on('confirmation', function(confNumber, receipt){ 
        //console.log("confNumber",confNumber,"receipt",receipt)
      })
      .on('error', function(error){ 
        console.log("error", error)
      })
      .then(function(receipt){
          console.log("Repaid Borrow completed!");
          console.log(receipt);                             // Print the entire receipt's transaction
          console.log(receipt.receipt.logs[0].args);          // Print all the results of emiting an Event
          //console.log(receipt.events.Swap.returnValues);
      });
    } catch(error) {
      console.log(error);
    }

    /*
    try {
      await swapTokensContract.swap(tokenIn.address,tokenOut.address,AMOUNT_IN,AMOUNT_OUT_MIN,TO, { from: TOKEN_B_WHALE })
      // When the receipt is received indicated that the transaction has been completed
      .once('receipt', function(receipt){
        console.log("Transaction completed"); 
        //console.log("receipt", receipt) 
      })
      .on('confirmation', function(confNumber, receipt){ 
        //console.log("confNumber",confNumber,"receipt",receipt)
      })
      .on('error', function(error){ 
        console.log("error", error)
      })
      .then(function(receipt){
          console.log("Swap completed!");
          //console.log(receipt);                             // Print the entire receipt's transaction
          console.log(receipt.receipt.logs[0].args);          // Print all the results of emiting an Event
          //console.log(receipt.events.Swap.returnValues);
      });
    } catch(error) {
      console.log(error);
    }


    */

    snap = await snapshot(testCompound, liquidator)
    console.log(`--- liquidated ---`)
    console.log(`close factor: ${snap.closeFactor} %`)
    console.log(`liquidation incentive: ${snap.incentive}`)
    console.log(`supplied: ${snap.supplied}`)
    console.log(`liquidity: $ ${snap.liquidity}`)
    console.log(`shortfall: $ ${snap.shortfall}`)
    console.log(`borrowed: ${snap.borrowed}`)
    console.log(`liquidated: ${snap.liquidated}`)

    /* memo
    c = 31572
    r = c * 0.65 * 0.5
    b = 1
    i = 1.08
    r * i * b / c
    */


    // ===================================================== //
    /**
     *             @logs
        Contract: CompoundBorrower
        suuply whale balance: 12000
        
        --- supplied ---
        col factor: 70 %
        supplied: 0.99

        --- entered market ---
        liquidity: $ 13409
        price: $ 1
        max borrow: 13399
        borrow amount: 13410

        --- borrowed ---
        liquidity: $ 0.6173
        borrowed: 13410.48
        @openzeppelin/test-helpers WARN advanceBlockTo: Advancing too many blocks is causing this test to be slow.

        --- after some blocks... ---
        liquidity: $ 0
        shortfall: $ 0.7135
        borrowed: 13411.81
        liquidator balance: 18998850
        amount to be liquidated (cToken collateral):  18.83
        Ether available in the LIQUIDATOR account before calling the liquidator() function:  12514154933888576612
        Transaction completed
        Repaid Borrow completed!

        --- liquidated ---
        close factor: 50 %
        liquidation incentive: 1.08
        supplied: 0.62
        liquidity: $ 1635.3937
        shortfall: $ 0
        borrowed: 6705.9
        liquidated: 0.3674
            ✓ should liquidate (120084ms)

     */


  })
})