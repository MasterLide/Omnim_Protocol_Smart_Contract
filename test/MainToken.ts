import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

describe("MainToken", async function () {
  const { viem } = await network.connect();
  const [senderClient, test] = await viem.getWalletClients();

  it("Should emit the Transfer event when calling the mint()/burn() function", async function () {
    const mainToken = await viem.deployContract("MainToken",[100000n,senderClient.account.address]);

    await viem.assertions.emit(
      mainToken.write.mint([test.account.address, 200000n]),
      mainToken,
      "Transfer",
    );

    assert.equal(200000n, await mainToken.read.balanceOf([test.account.address]));

    await viem.assertions.emit(
      mainToken.write.burn([20000n]),
      mainToken,
      "Transfer",
    );

    assert.equal(80000n, await mainToken.read.balanceOf([senderClient.account.address]));

  });
});
