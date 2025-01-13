import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import "@nomicfoundation/hardhat-verify";


import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    compilers:[
      {
      version: "0.8.28",
      settings:{
        evmVersion:"paris",
        optimizer: {
          enabled:true,
          runs:200
      }
      }
    }
    ],
  },

  gasReporter: {
    enabled: true,
    currency: "USD",
    gasPrice: 21,
    outputFile: "gas-report.txt",
    coinmarketcap:process.env.COINMARKETCAP_API,
    token:"ETH"

  },

  networks:{
    hardhat: {
      allowUnlimitedContractSize:true,
  },


  //base-sepolia 
  baseSepolia: {
    url: "https://sepolia.base.org",
    chainId: 84532,
    accounts: [process.env.PRIVATE_KEY as string],
  },
},

etherscan: {
  apiKey: {
    baseSepolia: process.env.BASESCAN_API as string,
  },
  customChains:[
    {
    
      network: "baseSepolia",
      chainId: 84532,
      urls: {
        apiURL: "https://base-sepolia.blockscout.com/api",
        browserURL: "https://base-sepolia.blockscout.com",
      },
    }

  ]


},

  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    deploy: "./deploy",
    artifacts: "./artifacts",
  },
  namedAccounts: {
    deployer: {
      default: 0, 
    },
  },
}



export default config;
