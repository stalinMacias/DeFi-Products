const { time } = require("@openzeppelin/test-helpers")
const assert = require("assert")
const BN = require("bn.js")
const { sendEther, pow } = require("./util")
const { DAI, DAI_WHALE, CDAI, WBTC, WBTC_WHALE, CWBTC } = require("./config")
const { web3 } = require("@openzeppelin/test-helpers/src/setup")

const IERC20 = artifacts.require("IERC20")
const CErc20 = artifacts.require("CErc20")
const CompoundERC20 = artifacts.require("CompoundERC20")

/**
 * @dev This test will simulate the process to borrow DAI Tokens from the compound protocol
 * The borrower will supply WBTC tokens to the compound protocol and will get cWBTC tokens in exchange for its WBTC
 * The cWBTC tokens will be used to enter the market and get liquidity in the protocol to ask for a borrow
 * After the borrower has enetered its cWBTC to the market and has been granted with liquidity will proceed to ask for a borrow of DAI Tokens!
 * 
 * The test will advance 5k blocks to simulate the total interests that would be accrued over the original loan
 * 
 * 
 * And finally, the borrower will repay its loan using the same token that was borrowed, in this case, DAI token!
 * The expected result is that the contract that asked the loan will get back the borrower's collateral (The cWBTC tokens)
 * 
 */
contract("CompoundERC20", (accounts) => {
  const WHALE = WBTC_WHALE
  const TOKEN = WBTC
  const C_TOKEN = CWBTC
  const TOKEN_TO_BORROW = DAI
  const C_TOKEN_TO_BORROW = CDAI
  const REPAY_WHALE = DAI_WHALE // used to repay interest on borrow

  const SUPPLY_DECIMALS = 8 //WBTC tokens is set to use 8 decimals ---> This value might vary from token to token, be ware of it!
  const SUPPLY_AMOUNT = pow(10, SUPPLY_DECIMALS).mul(new BN(1))
  const BORROW_DECIMALS = 18
  const BORROW_INTEREST = pow(10, BORROW_DECIMALS).mul(new BN(1000))

  let testCompound
  let token
  let cToken
  let tokenToBorrow
  let cTokenToBorrow
  beforeEach(async () => {
    await sendEther(web3, accounts[0], WHALE, 1)

    testCompound = await CompoundERC20.new(TOKEN, C_TOKEN)
    token = await IERC20.at(TOKEN)
    cToken = await CErc20.at(C_TOKEN)
    tokenToBorrow = await IERC20.at(TOKEN_TO_BORROW)
    cTokenToBorrow = await CErc20.at(C_TOKEN_TO_BORROW)

    const supplyBal = await token.balanceOf(WHALE)
    console.log(`suuply whale balance: ${supplyBal.div(pow(10, SUPPLY_DECIMALS))}`)
    assert(supplyBal.gte(SUPPLY_AMOUNT), "bal < supply")

    const borrowBal = await tokenToBorrow.balanceOf(REPAY_WHALE)
    console.log(`repay whale balance: ${borrowBal.div(pow(10, BORROW_DECIMALS))}`)
    assert(borrowBal.gte(BORROW_INTEREST), "bal < borrow interest")
  })

  const snapshot = async (testCompound, tokenToBorrow) => {
    //console.log(await testCompound.getAccountLiquidity());
    const { liquidity } = await testCompound.getAccountLiquidity()
    const colFactor = await testCompound.getCollateralFactor()
    const supplied = await testCompound.balanceOfUnderlying.call()
    const price = await testCompound.getPriceFeed(C_TOKEN_TO_BORROW)
    const maxBorrow = liquidity.div(price)
    const borrowedBalance = await testCompound.getBorrowedBalance.call(C_TOKEN_TO_BORROW)
    const tokenToBorrowBal = await tokenToBorrow.balanceOf(testCompound.address)
    const borrowRate = await testCompound.getBorrowRatePerBlock.call(C_TOKEN_TO_BORROW)

    return {
      colFactor: colFactor.div(pow(10, 18 - 2)) / 100,
      supplied: supplied.div(pow(10, SUPPLY_DECIMALS - 2)) / 100,
      price: price.div(pow(10, 18 - 2)) / 100,
      liquidity: liquidity.div(pow(10, 18)),
      maxBorrow,
      borrowedBalance: borrowedBalance.div(pow(10, BORROW_DECIMALS - 2)) / 100,
      tokenToBorrowBal: tokenToBorrowBal.div(pow(10, BORROW_DECIMALS - 2)) / 100,
      borrowRate,
    }
  }

  it("should supply, borrow and repay", async () => {
    // used for debugging
    let tx
    let snap

    // supply
    await token.approve(testCompound.address, SUPPLY_AMOUNT, { from: WHALE })

    tx = await testCompound.supply(SUPPLY_AMOUNT, {
      from: WHALE,
    })

    // borrow
    snap = await snapshot(testCompound, tokenToBorrow)
    console.log(`--- borrow (before) ---`)
    console.log(`col factor: ${snap.colFactor} %`)
    console.log(`supplied: ${snap.supplied}`)
    console.log(`liquidity: $ ${snap.liquidity}`)
    console.log(`price: $ ${snap.price}`)
    console.log(`max borrow: ${snap.maxBorrow}`)
    console.log(`borrowed balance (compound): ${snap.borrowedBalance}`)
    console.log(`borrowed balance (erc20): ${snap.tokenToBorrowBal}`)
    console.log(`borrow rate: ${snap.borrowRate}`)

    tx = await testCompound.borrow(C_TOKEN_TO_BORROW, BORROW_DECIMALS, { from: WHALE })
    // for (const log of tx.logs) {
    //   console.log(log.event, log.args.message, log.args.val.toString())
    // }

    snap = await snapshot(testCompound, tokenToBorrow)
    console.log(`--- borrow (after) ---`)
    console.log(`liquidity: $ ${snap.liquidity}`)
    console.log(`max borrow: ${snap.maxBorrow}`)
    console.log(`borrowed balance (compound): ${snap.borrowedBalance}`)
    console.log(`borrowed balance (erc20): ${snap.tokenToBorrowBal}`)

    // accrue interest on borrow
    const block = await web3.eth.getBlockNumber()
    await time.advanceBlockTo(block + 5000)  // Advance 5k block to see the total accrued interests on the original loan

    snap = await snapshot(testCompound, tokenToBorrow)
    console.log(`--- after some blocks... ---`)
    console.log(`liquidity: $ ${snap.liquidity}`)
    console.log(`max borrow: ${snap.maxBorrow}`)
    console.log(`borrowed balance (compound): ${snap.borrowedBalance}`)
    console.log(`borrowed balance (erc20): ${snap.tokenToBorrowBal}`)

    // repay
    await tokenToBorrow.transfer(testCompound.address, BORROW_INTEREST, { from: REPAY_WHALE })
    const MAX_UINT = pow(2, 256).sub(new BN(1))
    tx = await testCompound.repay(TOKEN_TO_BORROW, C_TOKEN_TO_BORROW, MAX_UINT, {
      from: REPAY_WHALE,
    })

    snap = await snapshot(testCompound, tokenToBorrow)
    console.log(`--- repay ---`)
    console.log(`liquidity: $ ${snap.liquidity}`)
    console.log(`max borrow: ${snap.maxBorrow}`)
    console.log(`borrowed balance (compound): ${snap.borrowedBalance}`)
    console.log(`borrowed balance (erc20): ${snap.tokenToBorrowBal}`)
  })
})

/*

              Tests Output:
  Contract: CompoundERC20
suuply whale balance: 11997
repay whale balance: 18997850
--- borrow (before) ---
col factor: 0.7 %
supplied: 0.99
liquidity: $ 0
price: $ 1
max borrow: 0
borrowed balance (compound): 0
borrowed balance (erc20): 0
borrow rate: 9879133200
--- borrow (after) ---
liquidity: $ 6708
max borrow: 6703
borrowed balance (compound): 6698.16
borrowed balance (erc20): 6698.16
@openzeppelin/test-helpers WARN advanceBlockTo: Advancing too many blocks is causing this test to be slow.
--- after some blocks... ---
liquidity: $ 6708
max borrow: 6703
borrowed balance (compound): 6698.49
borrowed balance (erc20): 6698.16
--- repay ---
liquidity: $ 13406
max borrow: 13396
borrowed balance (compound): 0
borrowed balance (erc20): 999.66
    ✓ should supply, borrow and repay (69274ms)

*/