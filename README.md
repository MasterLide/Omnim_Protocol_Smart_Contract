# Omnim_Protocol_Smart_Contract

This project is a Hardhat 3 Beta project using the native Node.js test runner (`node:test`) and the `viem` library for Ethereum interactions.

## Contract Overview

| Contract | Purpose | Access Control | Upgradable |
| ------ | ------ | ------ | ------ |
| VeToken | This is a non-transferrable voting token to be used to vote   | Ownable | / |
| TokenDAO | Base DAO to any. | - | / | 
| TokenFactory | Handles the application & instantiation of a new SubToken. References implementation and Persona NFT vault contracts are stored here. | Roles : DEFAULT_ADMIN_ROLE, WITHDRAW_ROLE | Y | 
| DataNft | This is the main registry. Used to save address.  | Roles: DEFAULT_ADMIN_ROLE, MINTER_ROLE | Y |
| SubToken | This is implementation contract for MainToken staking. TokenFactory will clone the SubToken instantiation. Staked token is non-transferable. | - | / |
| MinerPool | This is minepool. Staked token can mint mineToken on this. | Roles: GOV_ROLE, TOKEN_SAVER_ROLE | Y |
| MainToken | The main token | Ownable | N |

## Usage

### Running Tests

To run all the tests in the project, execute the following command:

```shell
npx hardhat test
```

### Make a deployment to local chain

To run the deployment use base module to a local chain:

```shell
npx hardhat ignition deploy ignition/modules/useBase.ts --network localhost
```
To run the deployment use proxy module to a local chain:

```shell
npx hardhat ignition deploy ignition/modules/useProxy.ts --network localhost
```

# Main Activities
## Stake and Mint
1. Approve some **MainToken** to **VeToken** 
2. Stake at **VeToken** (action = ```VeToken.stake``` ), It will :
    a. Transfer **MainToken** to **VeToken**
    b. Mint **VeToken**
    c. Start mint at **MinerPool**
3. Now you can propose/voting at **TokenDAO** 
4. Claim mines at **MinerPool** more days(action = ```MinerPool.claimMyMines``` )

## Create SubToken
1. Approve some **MainToken** to **TokenFactory** 
2. Propose SubToken infos at **TokenFactory**(action = ```TokenFactory.proposeSubToken``` ), it will do following:
	a. Clone **SubToken**
	b. Clone **TokenDAO**,(modelId = 0 is non)
	c. Mint **AgentNft**
	d. Stake MainToken to **VeToken**
	e. Start mint at **MinerPool** with **SubToken**
