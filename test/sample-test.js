const Greeter = artifacts.require("Greeter");
const ERC20_Reward_Token = artifacts.require("Dojo");
const ERC721_Staking_Token = artifacts.require("contracts/Ninja-NFT.sol:NFTContract");
const ERC1155_Staking_Token = artifacts.require("contracts/Staking-ERC1155.sol:Items");
const Staking_system = artifacts.require("contracts/Staking-System-Optimized.sol:StakingSystemRequired");
const { ethers } = require("hardhat");
const { expect } = require("chai");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Testing Staking System", function () {
  let accounts;
  let dojoContract;
  let landContract;
  let itemsContract;
  let stakingContract;
  let dojoBal;
  before(async function () {

    const ERC20_Reward_Token = await ethers.getContractFactory("Dojo");
    const ERC721_Staking_Token = await ethers.getContractFactory("contracts/Ninja-NFT.sol:NFTContract");
    const ERC1155_Staking_Token = await ethers.getContractFactory("contracts/Staking-ERC1155.sol:Items");
    const Staking_system = await ethers.getContractFactory("contracts/Staking-System-Optimized.sol:StakingSystemRequired");


    accounts = await hre.ethers.getSigners();

    dojoContract = await ERC20_Reward_Token.deploy();
    landContract = await ERC721_Staking_Token.deploy('', '', '');
    itemsContract = await ERC1155_Staking_Token.deploy();
    stakingContract = await Staking_system.deploy(landContract.address, itemsContract.address, dojoContract.address);

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
    await landContract.mint(accounts[0].address, 5)
    await landContract.mint(accounts[0].address, 5)
    await itemsContract.mintBatch(accounts[0].address, [0, 1, 2], [5, 5, 5], [])

    await stakingContract.connect(accounts[0]).stakeERC721(1)
    await stakingContract.connect(accounts[0]).stakeERC1155(0, 5)
    await stakingContract.GetStakedERC721(accounts[0].address, 1)
    await stakingContract.GetStakedERC1155(accounts[0].address, 0)
  });

  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Stake Owned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Stake Owned ERC 721 & ERC 115", function () {
    it("Should successfully stake owned tokens", async function () {
      expect(await landContract.balanceOf(accounts[0].address)).to.equal(14);
      expect(await itemsContract.balanceOf(accounts[0].address, 1)).to.equal(5);

      const stakeERC721 = await stakingContract.connect(accounts[0]).stakeERC721(2)
      const stakeERC1155 = await stakingContract.connect(accounts[0]).stakeERC1155(1, 5)

      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 1)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 0)

      expect(getStakedErc721.amount).to.equal(1);
      expect(getStakedErc1155[0].amount).to.equal(5);

      expect(await landContract.balanceOf(accounts[0].address)).to.equal(13);
      expect(await itemsContract.balanceOf(accounts[0].address, 1)).to.equal(0);

      expect(await landContract.balanceOf(stakingContract.address)).to.equal(2);
      expect(await itemsContract.balanceOf(stakingContract.address, 1)).to.equal(5);

    });
  });

  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Stake NonExistant ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Stake NonExistant ERC 721 & ERC 1155", function () {
    it("Should successfully reject stake nonexistant tokens", async function () {
      await expect(stakingContract.connect(accounts[0]).stakeERC721(50)).to.be.revertedWith('ERC721: owner query for nonexistent token')
      await expect(stakingContract.connect(accounts[0]).stakeERC1155(10, 5)).to.be.revertedWith('Account have less token')

      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 50)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 10)

      expect(getStakedErc721.amount).to.equal(0);
      expect(getStakedErc1155.length).to.equal(0);

    });
  });
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Stake Unowned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Stake Unowned ERC 721 & ERC 1155", function () {
    it("Should successfully reject stake unowned tokens", async function () {
      await expect(stakingContract.connect(accounts[1]).stakeERC721(0)).to.be.revertedWith('ERC721: owner query for nonexistent token')
      await expect(stakingContract.connect(accounts[1]).stakeERC1155(0, 5)).to.be.revertedWith('Account have less token')

      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[1].address, 0)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[1].address, 0)

      expect(getStakedErc721.amount).to.equal(0);
      expect(getStakedErc1155.length).to.equal(0);
    });
  });
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Staked Already Staked ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Stake Staked Already Staked ERC 721 & ERC 1155", function () {
    it("Should successfully reject stake already staked tokens", async function () {

      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 2)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 1)

      expect(getStakedErc721.amount).to.equal(1);
      expect(getStakedErc1155[0].amount).to.equal(5);

      await expect(stakingContract.connect(accounts[0]).stakeERC721(2)).to.be.revertedWith('Account doesnt own token')
      await expect(stakingContract.connect(accounts[0]).stakeERC1155(1, 5)).to.be.revertedWith('Account have less token')

      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 2)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 1)

      expect(getStakedErc721.amount).to.equal(1);
      expect(getStakedErc1155[0].amount).to.equal(5);
    });
  });
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Unstake Unowned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Unstake Unowned ERC 721 & ERC 1155", function () {
    it("Should successfully reject unstake Unowned ERC 721 & ERC 1155", async function () {
      
      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 1)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 0)
      var getDojoBalance = await dojoContract.balanceOf(accounts[1].address);
      expect(getStakedErc721.amount).to.equal(1);
      expect(getStakedErc1155[0].amount).to.equal(5);
      expect(getDojoBalance).to.equal(0);

      await expect(stakingContract.connect(accounts[1]).unstakeERC721(1)).to.be.revertedWith('Nft Staking System: user must be the owner of the staked nft')
      await expect(stakingContract.connect(accounts[1]).unstakeERC1155(5, 1)).to.be.revertedWith('Nft Staking System: user has no nfts of this type staked')

      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 1)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 0)
      var getDojoBalance = await dojoContract.balanceOf(accounts[1].address);
      //should expect no change since user B is trying to unstake user A's tokens 
      expect(getStakedErc721.amount).to.equal(1);
      expect(getStakedErc1155[0].amount).to.equal(5);
      expect(getDojoBalance).to.equal(0);
    });
  })
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Unstake Owned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Unstake Owned ERC 721 & ERC 1155", function () {
    it("Should successfully unstake Owned tokens", async function () {
      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 1)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 0)
      var getDojoBalance = await dojoContract.balanceOf(accounts[0].address);
      expect(getStakedErc721.amount).to.equal(1);
      expect(getStakedErc1155[0].amount).to.equal(5);
      expect(getDojoBalance).to.equal(0);

      await stakingContract.connect(accounts[0]).unstakeERC721(1)
      await stakingContract.connect(accounts[0]).unstakeERC1155(0, 0)

      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 1)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 0)
      var getDojoBalance = await dojoContract.balanceOf(accounts[0].address);

      expect(getStakedErc721.amount).to.equal(0);
      expect(getStakedErc1155.length).to.equal(0);
      expect(getDojoBalance).to.not.equal(0);

    });
  });

  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Unstake Nonexistant ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Unstake Nonexistant ERC 721 & ERC 1155", function () {
    it("Should successfully reject unstake Unowned ERC 721 & ERC 1155", async function () {
      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[1].address, 10)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[1].address, 10)
      var getDojoBalance = await dojoContract.balanceOf(accounts[1].address);
      expect(getStakedErc721.amount).to.equal(0);
      expect(getStakedErc1155.length).to.equal(0);
      expect(getDojoBalance).to.equal(0);

      await expect(stakingContract.connect(accounts[1]).unstakeERC721(10)).to.be.revertedWith('Nft Staking System: user must be the owner of the staked nft')
      await expect(stakingContract.connect(accounts[1]).unstakeERC1155(10, 1)).to.be.revertedWith('Nft Staking System: user has no nfts of this type staked')

      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[1].address, 10)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[1].address, 10)
      var getDojoBalance = await dojoContract.balanceOf(accounts[1].address);

      expect(getStakedErc721.amount).to.equal(0);
      expect(getStakedErc1155.length).to.equal(0);
      expect(getDojoBalance).to.equal(0);
    });
  })

  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Unstake Unstaked ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Unstake Unstaked ERC 721 & ERC 1155", function () {
    it("Should successfully reject unstake Unowned ERC 721 & ERC 1155", async function () {
      
      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 1)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 0)
      var getDojoBalanceA = await dojoContract.balanceOf(accounts[0].address);
      expect(getStakedErc721.amount).to.equal(0);
      expect(getStakedErc1155.length).to.equal(0);

      await  expect(stakingContract.connect(accounts[0]).unstakeERC721(1)).to.be.revertedWith('Nft Staking System: user must be the owner of the staked nft')
      await  expect(stakingContract.connect(accounts[0]).unstakeERC1155(0, 0)).to.be.revertedWith('Nft Staking System: user has no nfts of this type staked')

      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 1)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 0)
      var getDojoBalanceB = await dojoContract.balanceOf(accounts[0].address);

      expect(getStakedErc721.amount).to.equal(0);
      expect(getStakedErc1155.length).to.equal(0);
      expect(getDojoBalanceA - getDojoBalanceB).to.equal(0);
    });
  })
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ GET NONEMPTY STAKED ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Query for staked erc721 and erc1155", function () {
    it("Should successfully reject unstake Unowned ERC 721 & ERC 1155", async function () {
      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 2)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 1)

      
      expect(getStakedErc721.amount).to.equal(1);
      expect(getStakedErc1155[0].amount).to.equal(5);
    });
  })
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ GET EMPTY STAKED ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Query for already unstaked erc721 and erc1155", function () {
    it("Should successfully reject unstake Unowned ERC 721 & ERC 1155", async function () {
      var getStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 1)
      var getStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 0)

      expect(getStakedErc721.amount).to.equal(0);
      expect(getStakedErc1155.length).to.equal(0);
    });
  })

  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ GET EMPTY STAKED ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Query for nonstaked erc721 and erc1155 tokens", function () {
    it("Should successfully reject unstake Unowned ERC 721 & ERC 1155", async function () {
      var getEmptyStakedErc721 = await stakingContract.GetStakedERC721(accounts[0].address, 10)
      var getEmptyStakedErc1155 = await stakingContract.GetStakedERC1155(accounts[0].address, 10)

      expect(getEmptyStakedErc721.amount).to.equal(0);
      expect(getEmptyStakedErc1155.length).to.equal(0);
    });
  })

  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Batch Stake Owned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Batch Stake Owned ERC 721 & ERC 1155", function () {
    it("Should successfully reject unstake Unowned ERC 721 & ERC 1155", async function () {
      var erc271Balance =  await landContract.balanceOf(accounts[0].address)
      var erc1155ABalance =  await itemsContract.balanceOf(accounts[0].address, 0)
      var erc1155BBalance =  await itemsContract.balanceOf(accounts[0].address, 2)
      expect(erc1155ABalance).to.equal(5);
      expect(erc1155BBalance).to.equal(5);
      expect(erc271Balance).to.equal(14);
      
      await stakingContract.connect(accounts[0]).batchStakeERC721([1, 3])
      await stakingContract.connect(accounts[0]).batchStakeERC1155([0, 2], [5, 5])
      
      var erc271Balance =  await landContract.balanceOf(accounts[0].address)
      var erc1155ABalance =  await itemsContract.balanceOf(accounts[0].address, 0)
      var erc1155BBalance =  await itemsContract.balanceOf(accounts[0].address, 2)
      expect(erc1155ABalance).to.equal(0);
      expect(erc1155BBalance).to.equal(0);
      expect(erc271Balance).to.equal(12);
    });
  })


  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Batch Stake Unowned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Batch Stake Unowned ERC 721 & ERC 1155", function () {
    it("Should successfully reject unstake Unowned ERC 721 & ERC 1155", async function () {
      var erc271Balance =  await landContract.balanceOf(accounts[1].address)
      var erc1155ABalance =  await itemsContract.balanceOf(accounts[1].address, 0)
      var erc1155BBalance =  await itemsContract.balanceOf(accounts[2].address, 2)
      expect(erc1155ABalance).to.equal(0);
      expect(erc1155BBalance).to.equal(0);
      expect(erc271Balance).to.equal(0);

      await expect(stakingContract.connect(accounts[1]).batchStakeERC721([1, 2])).to.be.revertedWith('Account doesnt own token')
      await expect(stakingContract.connect(accounts[1]).batchStakeERC1155([0, 1, 2], [5, 5, 5])).to.be.revertedWith('Account have less token')

      var erc271Balance =  await landContract.balanceOf(accounts[1].address)
      var erc1155ABalance =  await itemsContract.balanceOf(accounts[1].address, 0)
      var erc1155BBalance =  await itemsContract.balanceOf(accounts[2].address, 2)
      expect(erc1155ABalance).to.equal(0);
      expect(erc1155BBalance).to.equal(0);
      expect(erc271Balance).to.equal(0);
    });
  })

  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Batch Stake Already Staked ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Batch Stake Already Staked ERC 721 & ERC 1155", function () {
    it("Should successfully reject unstake Unowned ERC 721 & ERC 1155", async function () {
      var erc271Balance =  await landContract.balanceOf(accounts[0].address)
      var erc1155ABalance =  await itemsContract.balanceOf(accounts[0].address, 0)
      var erc1155BBalance =  await itemsContract.balanceOf(accounts[0].address, 2)
      expect(erc1155ABalance).to.equal(0);
      expect(erc1155BBalance).to.equal(0);
      expect(erc271Balance).to.equal(12);

      await expect(stakingContract.connect(accounts[0]).batchStakeERC721([1, 3])).to.be.revertedWith('Account doesnt own token')
      await expect(stakingContract.connect(accounts[0]).batchStakeERC1155([0, 2], [5, 5])).to.be.revertedWith('Account have less token')
    
      var erc271Balance =  await landContract.balanceOf(accounts[0].address)
      var erc1155ABalance =  await itemsContract.balanceOf(accounts[0].address, 0)
      var erc1155BBalance =  await itemsContract.balanceOf(accounts[0].address, 2)
      expect(erc1155ABalance).to.equal(0);
      expect(erc1155BBalance).to.equal(0);
      expect(erc271Balance).to.equal(12);
    });
  })

  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Batch Unstake Owned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Batch Unstake Owned ERC 721 & ERC 1155", function () {
    it("Should successfully reject unstake Unowned ERC 721 & ERC 1155", async function () {
      var getStakedErc721A = await stakingContract.GetStakedERC721(accounts[0].address, 1)
      var getStakedErc721B = await stakingContract.GetStakedERC721(accounts[0].address, 2)
      var getStakedErc1155A = await stakingContract.GetStakedERC1155(accounts[0].address, 0)
      var getStakedErc1155B = await stakingContract.GetStakedERC1155(accounts[0].address, 0)
      expect(getStakedErc721A.amount).to.equal(1);
      expect(getStakedErc721B.amount).to.equal(1);
      expect(getStakedErc1155A[0].amount).to.equal(5);
      expect(getStakedErc1155B[0].amount).to.equal(5);
      
      var erc271Balance =  await landContract.balanceOf(accounts[0].address)
      var erc1155ABalance =  await itemsContract.balanceOf(accounts[0].address, 0)
      var erc1155BBalance =  await itemsContract.balanceOf(accounts[0].address, 2)
      expect(erc1155ABalance).to.equal(0);
      expect(erc1155BBalance).to.equal(0);
      expect(erc271Balance).to.equal(12);

      await stakingContract.connect(accounts[0]).batchUnstakeERC721([1, 2])
      await stakingContract.connect(accounts[0]).batchUnstakeERC1155([0, 2], [0, 0, 0])
      
      var getStakedErc721A = await stakingContract.GetStakedERC721(accounts[0].address, 1)
      var getStakedErc721B = await stakingContract.GetStakedERC721(accounts[0].address, 2)
      var getStakedErc1155A = await stakingContract.GetStakedERC1155(accounts[0].address, 0)
      var getStakedErc1155B = await stakingContract.GetStakedERC1155(accounts[0].address, 0)
      expect(getStakedErc721A.amount).to.equal(0);
      expect(getStakedErc721B.amount).to.equal(0);
      expect(getStakedErc1155A.length).to.equal(0);
      expect(getStakedErc1155B.length).to.equal(0);

      var erc271Balance =  await landContract.balanceOf(accounts[0].address)
      var erc1155ABalance =  await itemsContract.balanceOf(accounts[0].address, 0)
      var erc1155BBalance =  await itemsContract.balanceOf(accounts[0].address, 2)
      expect(erc1155ABalance).to.equal(5);
      expect(erc1155BBalance).to.equal(5);
      expect(erc271Balance).to.equal(14);
    });
  })

  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Batch Unstake Unowned ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Batch Unstake Unowned ERC 721 & ERC 1155", function () {
    it("Should successfully reject unstake Unowned ERC 721 & ERC 1155", async function () {
      await expect(stakingContract.connect(accounts[1]).batchUnstakeERC721([1, 2])).to.be.revertedWith('Nft Staking System: user must be the owner of the staked nft')
      await expect(stakingContract.connect(accounts[1]).batchUnstakeERC1155([0, 1, 2], [5, 5, 5])).to.be.revertedWith('Nft Staking System: user has no nfts of this type staked')
    });
  })
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Batch Unstake Already Staked ERC 721 & ERC 1155 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
  describe("Batch Unstake Already Staked ERC 721 & ERC 1155", function () {
    it("Should successfully reject unstake Unowned ERC 721 & ERC 1155", async function () {
      await expect(stakingContract.connect(accounts[0]).batchUnstakeERC721([1, 2])).to.be.revertedWith('Nft Staking System: user must be the owner of the staked nft')
      await expect(stakingContract.connect(accounts[0]).batchUnstakeERC1155([0, 1, 2], [5, 5, 5])).to.be.revertedWith('Nft Staking System: user has no nfts of this type staked')
    });
  })
});