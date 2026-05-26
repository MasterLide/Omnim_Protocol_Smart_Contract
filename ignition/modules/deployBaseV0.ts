import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import args from "./arguments.js"

export default buildModule("BaseV0Module", (m) => {
  const deployer = m.getAccount(0);
  const mainToken = m.contract("MainToken",[args.mainSuppy,deployer]);

  const veToken = m.contract("VeToken");

  const minerPool = m.contract("MinerPool");

  const subMinerPoolV0 = m.contract("SubMinerPoolV0");

  const subTokenV0 = m.contract("SubTokenV0");
  m.call(subTokenV0,"initialize",["Test USD","TUSD",18,args.mainSuppy,deployer]);

  const tokenFactoryV0 = m.contract("TokenFactoryV0");

  return { mainToken, veToken, minerPool, subMinerPoolV0, subTokenV0, tokenFactoryV0 };
});
