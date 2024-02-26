import { ethers } from "hardhat";

async function main() {
  const signers = await ethers.getSigners();

  const signerAccount = signers[0];
  console.log(`Signer account : ${signerAccount.address}`);

  // We get the contract to deploy
  const manager = await ethers.getContractFactory("TokenDistributionManager", {
    signer: signerAccount
  });

  // Skillon Token
  const tokenAddress = "0xD92B938F901656666F910361C264cA333CDA1b3d"; // [Testnet]

  // Deploy the contract
  const managerContract = await manager.deploy(tokenAddress);

  // Wait contract deploy process for complete
  await managerContract.deployed();

  console.log("Contract deployed to:", managerContract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
