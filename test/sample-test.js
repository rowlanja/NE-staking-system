const Greeter = artifacts.require("Greeter");
const ERC20_Reward_Token = artifacts.require("Dojo");
const ERC721_Staking_Token = artifacts.require("contracts/Ninja-NFT.sol:NFTContract");
const ERC1155_Staking_Token = artifacts.require("contracts/Staking-ERC1155.sol:Items");
const Staking_system = artifacts.require("contracts/Staking-System-Optimized.sol:StakingSystemRequired");
const { ethers } = require("hardhat");
const { expect } = require("chai");

// // Traditional Truffle test
// contract("Greeter", (accounts) => {
//   it("Should return the new greeting once it's changed", async function () {
//     const greeter = await Greeter.new("Hello, world!");
//     assert.equal(await greeter.greet(), "Hello, world!");

//     await greeter.setGreeting("Hola, mundo!");

//     assert.equal(await greeter.greet(), "Hola, mundo!");
//   });
// });

// // Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
// describe("Greeter contract", function () {
//   let accounts;

//   before(async function () {
//     accounts = await web3.eth.getAccounts();
//   });

//   describe("Deployment", function () {
//     it("Should deploy with the right greeting", async function () {
//       const greeter = await Greeter.new("Hello, world!");
//       assert.equal(await greeter.greet(), "Hello, world!");

//       const greeter2 = await Greeter.new("Hola, mundo!");
//       assert.equal(await greeter2.greet(), "Hola, mundo!");
//     });
//   });
// });

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Testing Staking System", function () {
  let accounts;
  let dojoContract;
  let landContract;
  let itemsContract;
  let stakingContract;

  before(async function () {

    const ERC20_Reward_Token = await ethers.getContractFactory("Dojo");
    const ERC721_Staking_Token = await ethers.getContractFactory("contracts/Ninja-NFT.sol:NFTContract");
    const ERC1155_Staking_Token = await ethers.getContractFactory("contracts/Staking-ERC1155.sol:Items");
    const Staking_system = await ethers.getContractFactory("contracts/Staking-System-Optimized.sol:StakingSystemRequired");


    accounts = await hre.ethers.getSigners();

    dojoContract = await ERC20_Reward_Token.deploy();
    landContract = await ERC721_Staking_Token.deploy('','','');
    itemsContract = await ERC1155_Staking_Token.deploy();
    stakingContract = await Staking_system.deploy(landContract.address, itemsContract.address, dojoContract.address );
    
    await dojoContract.deployed()
    await landContract.deployed()
    await itemsContract.deployed()
    await stakingContract.deployed()

    const mintRole = await dojoContract.MINTER_ROLE();

    await stakingContract.setTokensClaimable(1);
    await stakingContract.initStaking();
    await dojoContract.grantRole(mintRole, stakingContract.address);
    await landContract.setApprovalForAll(stakingContract.address, 1);
    await itemsContract.setApprovalForAll(stakingContract.address, 1);
    
    await landContract.mint(accounts[0].address, 5)
    await landContract.mint(accounts[0].address,5)
    await landContract.mint(accounts[0].address,5)
    await itemsContract.mintBatch(accounts[0].address, [0,1,2], [5,5,5], [])
  });

  describe("Minting ERC721_Staking_Token", function () {
    it("Should deploy with the right greeting", async function () {


        
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Stake System Tests ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
        console.log('balance : ', await landContract.balanceOf(accounts[0].address))
        console.log('balance : ', await itemsContract.balanceOf(accounts[0].address, 0))
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Stake Owned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
        const stakeERC721 = await stakingContract.connect(accounts[0]).stakeERC721(1)
        const stakeERC1155 = await stakingContract.connect(accounts[0]).stakeERC1155(0, 5)
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ GET STAKED ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
          var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address,1)
          console.log("Get Staked ERC721 | Expected 1 | Got : ", getStakedErc721.amount)

          var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address,0)
          console.log("Get Staked ERC1155 | Expected 5 | Got : ", getStakedErc1155[0].amount)

                
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Stake NonExistant ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
       
        await expect(stakingContract.connect(accounts[0]).stakeERC721(50)).to.be.revertedWith('ERC721: owner query for nonexistent token')
        await expect(stakingContract.connect(accounts[0]).stakeERC1155(10, 5)).to.be.revertedWith('Account have less token')

  
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Stake Unowned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
        await expect(stakingContract.connect(accounts[1]).stakeERC721(0)).to.be.revertedWith('ERC721: owner query for nonexistent token')
        await expect(stakingContract.connect(accounts[1]).stakeERC1155(0, 5)).to.be.revertedWith('Account have less token')

  
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Staked Already Staked ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
        await expect(stakingContract.connect(accounts[0]).stakeERC721(1)).to.be.revertedWith('Account doesnt own token')
        await expect(stakingContract.connect(accounts[0]).stakeERC1155(0, 5)).to.be.revertedWith('Account have less token')

        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Unstake Owned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
        try {
          var unstakeErc721 = await stakingContract.connect(accounts[0]).unstakeERC721(1)
          console.log("Unstake Owned ERC721 | Expected Result : True | Got : ", unstakeErc721.confirmations)
        } catch (e) {
          console.log("Unstake Owned ERC721 | Expected Result : True | Got : ", e)
        }
        try {
          var unstakeErc1155 = await stakingContract.connect(accounts[0]).unstakeERC1155(0, 0)
          console.log("Unstake Owned ERC1155 | Expected Result : True | Got : ",unstakeErc1155.confirmations)
        } catch (e) {
          console.log("Unstake Owned ERC1155 | Expected Result : True | Got : ",e)
        }
        
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Unstake Unowned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
        await expect(stakingContract.connect(accounts[1]).unstakeERC721(10)).to.be.revertedWith('Nft Staking System: user must be the owner of the staked nft')
        await expect(stakingContract.connect(accounts[1]).unstakeERC1155(10, 1)).to.be.revertedWith('Nft Staking System: user has no nfts of this type staked')

        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Unstake Unstaked ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
        await expect(stakingContract.connect(accounts[0]).unstakeERC721(0)).to.be.revertedWith('Nft Staking System: user must be the owner of the staked nft')
        await expect(stakingContract.connect(accounts[0]).unstakeERC1155(0, 0)).to.be.revertedWith('Nft Staking System: user has no nfts of this type staked')

        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ GET EMPTY STAKED ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

          var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, '1')
          console.log("Get Staked ERC721 | Expected ItemInfo | Got : ", getStakedErc721.amount)

          var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, '0')
          console.log("Get Staked ERC1155 | Expected ItemInfo | Got : ", getStakedErc1155)

        
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ GET EMPTY STAKED ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

          var getEmptyStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 10)
          console.log("Empty staked ERC721 | Expected 0 | Got : ", getEmptyStakedErc721.amount)

          var getEmptyStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 10)
          console.log("Empty staked ERC1155 | Expected [] | Got : ", getEmptyStakedErc1155)

        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Batch Stake Owned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
        var batchStakedErc721 = await stakingContract.connect(accounts[0]).batchStakeERC721([1,2])
        console.log("Batch stake ERC721 | Expected 1 | Got : ", batchStakedErc721.confirmations)
        
        
        var batchStakedErc1155 = await stakingContract.connect(accounts[0]).batchStakeERC1155([0,1,2],[5,5,5])
        console.log("Batch stake ERC1155 | Expected 1 | Got : ", batchStakedErc1155.confirmations)
        
        
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Batch Stake Unowned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
        await expect(stakingContract.connect(accounts[1]).batchStakeERC721([1,2])).to.be.revertedWith('Account doesnt own token')
        await expect(stakingContract.connect(accounts[1]).batchStakeERC1155([0,1,2],[5,5,5])).to.be.revertedWith('Account have less token')
      
        
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Batch Stake Already Staked ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
        await expect(stakingContract.connect(accounts[0]).batchStakeERC721([1,2])).to.be.revertedWith('Account doesnt own token')        
          await expect(stakingContract.connect(accounts[0]).batchStakeERC1155([0,1,2],[5,5,5])).to.be.revertedWith('Account have less token')        
        
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Batch Unstake Owned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
        var batchUnstakeErc721 = await stakingContract.connect(accounts[0]).batchUnstakeERC721(['1','2'])
        console.log("Batch Unstake Owned Staked ERC721 | Expected 1 | Got : ", batchUnstakeErc721.confirmations)
        
        var batchUnstakeErc1155 = await stakingContract.connect(accounts[0]).batchUnstakeERC1155([0,1,2],[0,0,0])
        console.log("Batch Unstake Owned Staked ERC1155 | Expected 1 | Got : ", batchUnstakeErc1155.confirmations)

        // console.log('balance : ', await landContract.balanceOf(accounts[0].address))
        // console.log('balance : ', await itemsContract.balanceOf(accounts[0].address, 0))
        // console.log('balance : ', await itemsContract.balanceOf(accounts[0].address, 1))
        // console.log('balance : ', await itemsContract.balanceOf(accounts[0].address, 2))
        
        // console.log('balance : ', await stakingContract.GetAllStakedERC1155(accounts[0].address))
        // console.log('balance : ', await stakingContract.GetAllStakedERC721(accounts[0].address))
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Batch Unstake Unowned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
        await expect(stakingContract.connect(accounts[1]).batchUnstakeERC721([1,2])).to.be.revertedWith('Nft Staking System: user must be the owner of the staked nft')        
        await expect(stakingContract.connect(accounts[1]).batchUnstakeERC1155([0,1,2],[5,5,5])).to.be.revertedWith('Nft Staking System: user has no nfts of this type staked')        
        
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Batch Unstake Already Staked ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
        await expect(stakingContract.connect(accounts[0]).batchUnstakeERC721([1,2])).to.be.revertedWith('Nft Staking System: user must be the owner of the staked nft')        
        await expect(stakingContract.connect(accounts[0]).batchUnstakeERC1155([0,1,2],[5,5,5])).to.be.revertedWith('Nft Staking System: user has no nfts of this type staked')        

    });
  });
});