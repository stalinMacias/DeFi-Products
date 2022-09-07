const IERC20 = artifacts.require("IERC20");

contract("IERC20", (accounts) => {
  const DAI="0x6b175474e89094c44da98b954eedeac495271d0f"
  const DAI_WHALE="0x5777d92f208679db4b9778590fa3cab3ac9e2168"

  it("get DAI Balance" , async () => {
    const dai = await IERC20.at(DAI)
    //console.log("dai: ", dai);
    const bal = await dai.balanceOf(DAI_WHALE)
    console.log(`bal: ${bal}`);
  });

  it("should transfer DAIs" , async () => {
    const dai = await IERC20.at(DAI)
    const daiWhaleOriginalBalance = await dai.balanceOf(DAI_WHALE)
    await dai.transfer(accounts[0], daiWhaleOriginalBalance, { from : DAI_WHALE })
    const accountReceivedDaiBalance = await dai.balanceOf(accounts[0])
    console.log(`Account that receives the dai new balance is: " ${accountReceivedDaiBalance}`);
  })


});