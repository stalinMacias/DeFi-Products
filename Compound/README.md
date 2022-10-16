# Resources:
  * Testing Mainnet Smart Contracts using Truffle and Ganache
    * https://www.youtube.com/watch?v=G8bDhS24eds

## Run in the linux console the below commands

  * Install required packages/tools
    * npm install ganache-cli truffle

  * Set INFURA_API_KEY
    * INFURA_API_KEY=<INFURA_API_KEY>

  * Create the fork:
    * npx ganache-cli --fork https://mainnet.infura.io/v3/$INFURA_API_KEY --networkId 999

<br>

  * Create a new entry for the mainnet-fork in the networks section in the truffle-config.js file
```
module.exports = {
  networks: {
    mainnet_fork: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "999",
    },
  }
}
```
## Addresses - from mainnet
### Uniswap V2 Contracts Addresses
UNISWAP_FACTORY=0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
UNISWAP_V2_ROUTER=0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D


### ERC20 Tokens Addresses
DAI=0x6B175474E89094C44Da98b954EedeAC495271d0F
WETH=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
WBTC=0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599
USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDT=0xdAC17F958D2ee523a2206206994597C13D831ec7

### Accounts Addresses
const DAI_WHALE = "0x7c8CA1a587b2c4c40fC650dB8196eE66DC9c46F4"
const USDC_WHALE ="0x55FE002aefF02F77364de339a1292923A15844B8" // Circle
const USDT_WHALE = "0x89e51fA8CA5D66cd220bAed62ED01e8951aa7c40"  //Kraken7
const WETH_WHALE = "0x3FE0bF87b9fFf545A85ADc63eC93aCC46B7Ca542"
const WBTC_WHALE = "0x218B95BE3ed99141b0144Dba6cE88807c4AD7C09"


<br>

## Forking Ganache unlocking an account - Run the below commands in the console

### The below parameters are defined in the .env file
  DAI_WHALE=0x7c8CA1a587b2c4c40fC650dB8196eE66DC9c46F4
  WETH_WHALE=0x3FE0bF87b9fFf545A85ADc63eC93aCC46B7Ca542
  INFURA_API_KEY=<INFURA_API_KEY>


#### Load the .env variables into the console
source ./.env

#### Run the ganache-cli --form command directly from the console
```
npx ganache-cli --fork https://mainnet.infura.io/v3/$INFURA_API_KEY --unlock 0x7c8CA1a587b2c4c40fC650dB8196eE66DC9c46F4 --unlock 0x3FE0bF87b9fFf545A85ADc63eC93aCC46B7Ca542 --unlock 0x218B95BE3ed99141b0144Dba6cE88807c4AD7C09 --networkId 999
```

* Equivalent of the above command: - For a strange reason using the env variables is not working even though the env vars are indeed loaded in the terminal - weird

npx ganache-cli --fork https://mainnet.infura.io/v3/$INFURA_API_KEY --secure --unlock $DAI_WHALE --unlock $WETH_WHALE --networkId 999


```
ganache-cli --secure --unlock "0x1234..." --unlock "0xabcd..."
```
* -u or --unlock: Specify --unlock ... any number of times passing either an address or an account index to unlock specific accounts. When used in conjunction with --secure, --unlock will override the locked state of specified accounts.
