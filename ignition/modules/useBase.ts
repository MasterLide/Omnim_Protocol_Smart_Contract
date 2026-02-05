import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

import BaseModule from "./deployBase.js"
import * as args from "./arguments.js"

export default buildModule("UseBaseModule", (m) => {
  const deployer = m.getAccount(0);
  const { mainToken, veToken, tokenDAO, minerPool, dataNft, subToken, tokenFactory } = m.useModule(BaseModule);

  m.call(veToken, "initialize", ["VeMainToken","VMT",deployer,mainToken,0n,true]);
  m.call(tokenDAO,"initialize",["TokenDAO",veToken,args.threshold,args.votingPeriod]);
  m.call(minerPool,"initialize",[mainToken,veToken,args.dayMines,args.decayPerDay,args.mineBase,args.mineAddPerDay]);  
  m.call(dataNft,"initialize",[deployer]);
  m.call(tokenFactory,"initialize",[subToken, mainToken, veToken, subToken, dataNft, args.threshold, deployer]);

  m.call(dataNft,"grantRole",[m.staticCall(dataNft,"MINTER_ROLE"), tokenFactory]);
  m.call(minerPool,"grantRole",[m.staticCall(minerPool,"GOV_ROLE"),deployer]);

  m.call(veToken,"setMiner",[minerPool]);

  m.call(mainToken,"approve",[veToken,args.stakeAmount]);
  m.call(veToken,"stake",[args.stakeAmount,deployer,deployer]);
  m.call(mainToken,"mint",[minerPool,args.suppyMines]);   

  m.call(mainToken,"transferOwnership",[tokenDAO]);

  return { mainToken, veToken, tokenDAO, minerPool, dataNft, subToken, tokenFactory };
});
