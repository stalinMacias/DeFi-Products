const BN = require("bn.js");
const IERC20 = artifacts.require("IERC20");
const SwapTokensContract = artifacts.require("SwapTokens");

contract("Testing a swap from DAI to WBTC" , (accounts) => {
  const DAI="0x6b175474e89094c44da98b954eedeac495271d0f"
  const DAI_WHALE="0x7c8CA1a587b2c4c40fC650dB8196eE66DC9c46F4"
  const WBTC="0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599"

  const WHALE = DAI_WHALE;
  const daiAmount = 10000; // 100k DAIs
  const AMOUNT_IN = new BN(10).pow(new BN(18)).mul(new BN(daiAmount));
  const AMOUNT_OUT_MIN = 1;
  const TOKEN_IN = DAI;
  const TOKEN_OUT = WBTC;
  const TO = accounts[0]; // The account that will receive the OUTPUT_TOKENS


  it("Swapping DAI for BTC", async () => {
    const tokenIn = await IERC20.at(TOKEN_IN);    // tokenIn contract - To access the address = tokenIn.address
    const tokenOut = await IERC20.at(TOKEN_OUT);  // tokenOut contract - To access the address = tokenOut.address

    console.log(`Original DAI Balance from the WHALE Account ${await tokenIn.balanceOf(WHALE)}`);

    const swapTokensContract = await SwapTokensContract.new();
    await tokenIn.approve(swapTokensContract.address, AMOUNT_IN, { from: WHALE });

    try {
      await swapTokensContract.swap(tokenIn.address,tokenOut.address,AMOUNT_IN,AMOUNT_OUT_MIN,TO, { from: WHALE })
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
          console.log(receipt.receipt.logs[0].args.tokenIn);  // Print an specific value from emitting an Event
          //console.log(receipt.events.Swap.returnValues);
      });
    } catch(error) {
      console.log(error);
    }
      
    //console.log("response: ", resp);
    console.log(`out ${await tokenOut.balanceOf(TO)}`);
  })

})