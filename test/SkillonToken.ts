import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, ContractFactory } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("SkillonToken", function() {
  // Constructor arguments
  const tokenName = "Skillon";
  const tokenSymbol = "SKILL";
  const initialSupply = 50_000_000; // Initial supply for current chain

  let erc20: Contract;
  let erc20Factory: ContractFactory;
  let deployer: SignerWithAddress;
  let account1: SignerWithAddress;

  beforeEach(async function() {
    [deployer, account1] = await ethers.getSigners();

    // We get the contract to deploy
    erc20Factory = await ethers.getContractFactory("Skillon");

    // Deploy the contract
    erc20 = await erc20Factory.deploy(tokenName, tokenSymbol, initialSupply);

    // Wait contract deploy process for complete
    await erc20.deployed();
  });

  it("Basic ERC20 Parameters", async function() {
    await expect(await erc20.decimals(), "Token decimals").to.equal(8);
    await expect(await erc20.name(), "Token name").to.equal(tokenName);
    await expect(await erc20.symbol(), "Token symbol").to.equal(tokenSymbol);
  });

  it("Owner Balance / Total Supply / Update balances after transfers", async function() {
    const ownerBalance = await erc20.balanceOf(deployer.address);
    await expect(await erc20.totalSupply(), "Total supply").to.equal(ownerBalance);

    // Transfer to account1
    await erc20.transfer(account1.address, 300);

    // Balance checks
    const finalOwnerBalance = await erc20.balanceOf(deployer.address);
    await expect(finalOwnerBalance).to.equal(ownerBalance.sub(300));

    const acc1Balance = await erc20.balanceOf(account1.address);
    await expect(acc1Balance).to.equal(300);
  });

  it("Burn Functionality", async function() {
    const ownerBalance = await erc20.balanceOf(deployer.address);

    await erc20.burn(500);
    await expect(await erc20.balanceOf(deployer.address), "Burn").to.equal(ownerBalance.sub(500));
  });

});
