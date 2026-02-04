import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { encodeFunctionData } from "viem";

describe("TokenDAO", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [senderClient, test] = await viem.getWalletClients();

  it("Should able to propose/castVote and auto early execution when forVotes == totalSupply", async function () {
    const mainToken = await viem.deployContract("MainToken",[100000n,senderClient.account.address]);

    const veToken = await viem.deployContract("VeToken");
    await veToken.write.initialize(["vetes","vts",test.account.address,mainToken.address,0n,true]);

    const tokenDAO = await viem.deployContract("TokenDAO");
    await tokenDAO.write.initialize(["TokenDAO",veToken.address,100n,5]);

    await mainToken.write.approve([veToken.address,200n]);
    await veToken.write.stake([200n,senderClient.account.address,test.account.address]);
    await mainToken.write.transferOwnership([tokenDAO.address]);
    const cd = encodeFunctionData({abi:mainToken.abi,functionName: "mint",args: [test.account.address,5000n]});
    await viem.assertions.revertWithCustomError(
      tokenDAO.write.propose([[mainToken.address],[0n],[cd],"test"]),
      tokenDAO,
      "GovernorInsufficientProposerVotes"
    );
    const proposeBlockNumber = await publicClient.getBlockNumber();
    
    await viem.assertions.emit(
      test.writeContract({
        address: tokenDAO.address,
        abi:tokenDAO.abi,
        functionName: 'propose',
        args: [[mainToken.address],[0n],[cd],"test"],
      }),
      tokenDAO,
      "ProposalCreated"
    )
    assert.equal(1n, await tokenDAO.read.proposalCount());

    const events = await publicClient.getContractEvents({
      address: tokenDAO.address,
      abi: tokenDAO.abi,
      eventName: "ProposalCreated",
      fromBlock: proposeBlockNumber,
      strict: true,
    });

    var pid = 0n;
    for (const event of events) {
      if (event.args.description == "test"){
        pid = event.args.proposalId;
      }
    }

    assert.equal(test.account.address, (await tokenDAO.read.proposalProposer([pid])).toLowerCase());

    await viem.assertions.emit(
      test.writeContract({
        address: tokenDAO.address,
        abi:tokenDAO.abi,
        functionName: 'castVote',
        args: [pid,1],
      }),
      tokenDAO,
      "VoteCast"
    )

    assert.equal(5000n, await mainToken.read.balanceOf([test.account.address]));
  });

});
