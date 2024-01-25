import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "@openzeppelin/hardhat-upgrades";

dotenv.config();

/**
 * Hardhat test accounts
 */
const hardhatAccounts = [
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
  "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",
  "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6",
  "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a",
  "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba",
  "0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e",
  "0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356",
  "0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97",
  "0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6",
  "0xf214f2b2cd398c806f84e317254e0f0b801d0643303237d97a22a48e01628897",
  "0x701b615bbdfb9de65240bc28bd21bbc0d996645a3dd57e7b12bc2bdf6f192c82",
  "0xa267530f49f8280200edf313ee7af6b827f2a8bce2897751d06a843f644967b1",
  "0x47c99abed3324a2707c28affff1267e45918ec8c3f20b8aa892e8b065d2942dd",
  "0xc526ee95bf44d8fc405a158bb884d9d1238d99f0612e9f33d006bb0789009aaa",
  "0x689af8efa8c651a91ad287602527f3af2fe9f6501a7ac4b061667b5a93e037fd",
  "0xde9be858da4a475276426320d5e9262ecfc3ba460bfac56360bfa6c4c28b4ee0",
  "0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e"
];

// Comma separated accounts
const mainnetAccounts: string[] = (process.env.ACCOUNTS_MAINNET || "").split(",");
const testnetAccounts: string[] = (process.env.ACCOUNTS_TESTNET || "").split(",");

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    local: {
      url: "http://127.0.0.1:7545",
      accounts: hardhatAccounts,
      chainId: 5777
    },
    hardhatLocal: {
      url: "http://127.0.0.1:8545",
      accounts: hardhatAccounts,
      chainId: 31337
    },
    ethereum: {
      url: "https://cloudflare-eth.com",
      accounts: mainnetAccounts,
      chainId: 1
    },
    baseChain: {
      url: "https://developer-access-mainnet.base.org",
      accounts: mainnetAccounts,
      chainId: 8453
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org/",
      accounts: mainnetAccounts,
      chainId: 56
    },
    polygon: {
      url: "https://polygon-rpc.com/",
      accounts: mainnetAccounts,
      chainId: 137,
      gasPrice: 500_000000000
    },
    avaxc: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      accounts: mainnetAccounts,
      chainId: 43114
    },
    bscTest: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      accounts: testnetAccounts,
      chainId: 97
    },
    avaxcTest: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      accounts: testnetAccounts,
      chainId: 43113
    },
    polygonTest: {
      url: "https://matic-mumbai.chainstacklabs.com",
      accounts: testnetAccounts,
      chainId: 80001
    }
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD"
  },
  etherscan: {
    apiKey: process.env.BSCSCAN_API_KEY
  }
};

export default config;
