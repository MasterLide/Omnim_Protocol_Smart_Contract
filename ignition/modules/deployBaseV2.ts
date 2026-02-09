import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import args from "./arguments.js"

export default buildModule("BaseV2Module", (m) => {
  const deployer = m.getAccount(0);
  const mainToken = m.contract("MainToken",[args.mainSuppy,deployer]);

  const veToken = m.contract("VeToken");

  const tokenDAO = m.contract("TokenDAO");

  const minerPool = m.contract("MinerPool");

  const dataNft = m.contract("DataNft");

  const subToken = m.contract("SubToken");
  m.call(subToken,"initialize",["Test USD","TUSD",18,args.mainSuppy,deployer]);

  const tokenFactoryV2 = m.contract("TokenFactoryV2");

  const subMinerPool = m.contract("SubMinerPool");

  return { mainToken, veToken, tokenDAO, minerPool, dataNft, subToken, tokenFactoryV2, subMinerPool};
});
