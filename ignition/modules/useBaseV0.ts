import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

import BaseV0Module from "./deployBaseV0.js"
import args from "./arguments.js"

export default buildModule("UseBaseV0Module", (m) => {
  const deployer = m.getAccount(0);
  const { mainToken, veToken, minerPool, subMinerPoolV0, subTokenV0, tokenFactoryV0 } = m.useModule(BaseV0Module);

  m.call(veToken, "initialize", ["VeMainToken","VMT",deployer,mainToken,0n,true]);
  m.call(minerPool,"initialize",[mainToken,veToken,args.dayMines,args.decayPerDay,args.mineBase,args.mineAddPerDay]);  
  m.call(tokenFactoryV0,"initialize",[subTokenV0, mainToken, veToken, veToken, subMinerPoolV0]);

  m.call(minerPool,"grantRole",[m.staticCall(minerPool,"GOV_ROLE"),deployer]);

  m.call(veToken,"setMiner",[minerPool]);

  m.call(mainToken,"approve",[veToken,args.stakeAmount]);
  m.call(veToken,"stake",[args.stakeAmount,deployer,deployer]);
  m.call(mainToken,"mint",[minerPool,args.suppyMines]);   

  return { mainToken, veToken, minerPool, subMinerPoolV0, subTokenV0, tokenFactoryV0 };
});
