import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

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
    baseSepolia: "getanAPIKEYLOL"
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


}
}



export default config;
