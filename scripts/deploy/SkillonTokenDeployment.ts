import { ethers } from "hardhat";

async function main() {
  const signers = await ethers.getSigners();

  const signerAccount = signers[0];
  console.log(`Signer account : ${signerAccount.address}`);

  // We get the contract to deploy
  const tokenErc20 = await ethers.getContractFactory("Skillon", {
    signer: signerAccount
  });

  // Constructor arguments
  const tokenName = "Skillon";
  const tokenSymbol = "SKILL";
  const initialSupply = 100_000_000;

  // Deploy the contract
  const tokenErc20Contract = await tokenErc20.deploy(tokenName, tokenSymbol, initialSupply);

  // Wait contract deploy process for complete
  await tokenErc20Contract.deployed();

  console.log("ERC20 deployed to:", tokenErc20Contract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
