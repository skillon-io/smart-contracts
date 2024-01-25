import * as dotenv from "dotenv";

const Web3 = require("web3");
const web3 = new Web3();

dotenv.config();

async function main() {
  const addressCount = 10;
  const entropy = process.env.GENERATOR_ENTROPY || "Entropy party: dishes piled, guests gone.";
  const prefix: string = process.env.GENERATOR_PREFIX;
  if (!prefix) {
    throw new Error(`Address prefix is not defined`);
  }

  console.log(`Trying to find addresses with prefix: ${prefix}`);
  console.log(`You should make sure that your terminal not being watched :)`);
  console.log(`------------------------------------------------------------`);

  let foundAddressCounter = 0;
  while (foundAddressCounter < addressCount) {
    const notReallyRandom = Math.floor(Math.random() * (2 ** 64 - 1));
    const account = web3.eth.accounts.create(`${entropy} - ${notReallyRandom}`);

    const newBornAccountPrefix = account.address.substring(0, prefix.length);
    if (newBornAccountPrefix.toLowerCase() === prefix.toLowerCase()) {
      console.log(`Address: ${account.address} , PrivateKey: ${account.privateKey}`);
      ++foundAddressCounter;
    }
  }

  console.log(`Done`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
