import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const mainSuppy = 100000000000000000000000000n;

export default buildModule("BaseModule", (m) => {
  const deployer = m.getAccount(0);
  const mainToken = m.contract("MainToken",[mainSuppy,deployer]);

  const veToken = m.contract("VeToken");

  const tokenDAO = m.contract("TokenDAO");

  const minerPool = m.contract("MinerPool");

  const dataNft = m.contract("DataNft");

  const subToken = m.contract("SubToken");
  m.call(subToken,"initialize",["Test USD","TUSD",18,mainSuppy,0n,deployer]);

  const tokenFactory = m.contract("TokenFactory");

  return { mainToken, veToken, tokenDAO, minerPool, dataNft, subToken, tokenFactory };
});
