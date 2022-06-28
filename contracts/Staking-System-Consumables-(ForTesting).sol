// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "hardhat/console.sol";

/*
Q1 : For minimum staking period we want nfts to be unstakable whenever even before the minimum staking period however we dont want staking rewards claimable before minimum period 
*/

/*
To Do : 
If a user stakes an erc1155 and then stakes another erc1155 at a later date how do we keep these seperate. The later stake currently overrides the previous stake
*/

interface IRewardToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract StakingSystemRequired is Ownable, ERC721Holder, ReentrancyGuard, Pausable  {
    IRewardToken public rewardsToken;
    IERC721 public land;
    IERC1155 public items;
    IERC1155 public consumables;

    uint256 stakingPeriod = 1 seconds;
    uint256 stakingMinimum = 1 days;
    uint256 stakingUnlock = 1 days;
    uint256 constant token = 10e18;
    
    bool public tokensClaimable;
    bool initialised;
    
    mapping(uint16 => Consumable) consumable;
    
    struct ItemInfo {
        uint256 amount;
        uint256 timestamp;
        uint16 bonus;
    }

    struct Consumable {
        uint16 timeReduced;
        uint16 rewardIncreased;
    }
    
    struct Staker {
        mapping(uint256 => ItemInfo[]) multiToken;
        mapping(uint256 => ItemInfo) token;

        uint256[] ownedMultiTokens;
        uint256[] ownedTokens;
        uint256 claimReward;

    }

    constructor(IERC721 _land, IERC1155 _items, IERC1155 _consumables, IRewardToken _rewardsToken) {
        items = _items;
        land = _land;
        rewardsToken = _rewardsToken;
        consumables = _consumables;
    }

    /// @notice mapping of a staker to its wallet
    mapping(address => Staker) public stakers;

    /// @notice event emitted when a user has staked a nft
    event Staked(address owner, uint256 id);
    event Staked(address owner, uint256 id, uint256 amount);

    /// @notice event emitted when a user has unstaked a nft
    event Unstaked(address owner, uint256 id);
    event Unstaked(address owner, uint256 id, uint256 amount);

    /// @notice event emitted when a user claims reward
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice Allows reward tokens to be claimed
    event ClaimableStatusUpdated(bool status);

    function initStaking() public onlyOwner {
        require(!initialised, "Already initialised");
        initialised = true;
    }

    function setTokensClaimable(bool _enabled) public onlyOwner {
        tokensClaimable = _enabled;
        emit ClaimableStatusUpdated(_enabled);
    }

    function setMinimumStakingPeriod(uint256 _period) public onlyOwner {
        stakingMinimum = _period;
    }

    function setUnlockPeriod(uint256 _period) public onlyOwner {
        stakingUnlock = _period;
    }

    function GetStakedERC721(address _user, uint256 _tokenId) view public returns(ItemInfo memory) {
        return stakers[_user].token[_tokenId];
    }

    function GetStakedERC1155(address _user, uint256 _tokenId) view public returns(ItemInfo[]  memory) {
        return stakers[_user].multiToken[_tokenId];
    }

    function GetAllStakedERC721(address _user) public view returns (uint256[] memory tokenIds)
    {
        return stakers[_user].ownedTokens;
    }

    function GetAllStakedERC1155(address _user) public view returns (uint256[] memory tokenIds)
    {
        return stakers[_user].ownedMultiTokens;
    }

    function stakeERC721(uint256 tokenId, uint16 consumable) public {
        require(initialised, "Staking System: the staking has not started");
        require(land.ownerOf(tokenId) == msg.sender , "Account doesnt own token");
        require(consumables.balanceOf(msg.sender, tokenId) > 0, "Account have less token");
        _stakeERC721(msg.sender, tokenId, consumable);
    }


    
    function stakeERC1155(uint256 tokenId, uint256 tokenAmount, uint16 consumable) public  {
        require(initialised, "Staking System: the staking has not started");
        require(items.balanceOf(msg.sender, tokenId) > 0, "Account have less token");
        require(consumables.balanceOf(msg.sender, tokenId) > 0, "Account have less token");        
        _stakeERC1155(msg.sender, tokenId, tokenAmount, consumable);
    }


    // function batchStakeERC721(uint256[] memory tokenIds) public {
    //     require(initialised, "Staking System: the staking has not started");
    //     for (uint256 i = 0; i < tokenIds.length; i++) {
    //         require(land.ownerOf(tokenIds[i]) == msg.sender , "Account doesnt own token");
    //         _stakeERC721(msg.sender, tokenIds[i]);
    //     }
    // }

    // function batchStakeERC1155(uint256[] memory tokenIds, uint256[] memory tokenAmounts, uint16[] memory consumables, uint16[] memory consumableAmounts) public {
    //     require(initialised, "Staking System: the staking has not started");
    //     for (uint256 i = 0; i < tokenIds.length; i++) {
    //         require(items.balanceOf(msg.sender, tokenIds[i]) > 0, "Account have less token");
    //         _stakeERC1155(msg.sender, tokenIds[i], tokenAmounts[i], consumables[i], consumableAmounts[i]);
    //     }
    // }

    function _stakeERC721(address _user, uint256 _tokenId, uint16 _consumableID) private nonReentrant{
        consumables.safeTransferFrom(_user, address(this), _consumableID, 1, "");
        land.safeTransferFrom(_user, address(this), _tokenId);

        Staker storage staker = stakers[_user];
        Consumable memory boost = consumable[_consumableID];
        ItemInfo memory info = ItemInfo(1,(block.timestamp+boost.timeReduced), boost.rewardIncreased);

        staker.token[_tokenId] = info;
        staker.ownedTokens.push(_tokenId);

        emit Staked(_user, _tokenId);
    }

    function _stakeERC1155(address _user, uint256 _tokenId, uint256 _tokenAmount, uint16 _consumableID) private nonReentrant {
        consumables.safeTransferFrom(_user, address(this), _consumableID, 1, "");

        items.safeTransferFrom(_user, address(this), _tokenId, _tokenAmount, "");
        Staker storage staker = stakers[_user];
        Consumable memory boost = consumable[_consumableID];
        ItemInfo memory info = ItemInfo(_tokenAmount,(block.timestamp+boost.timeReduced), boost.rewardIncreased);
        
        if(staker.multiToken[_tokenId].length == 0) {staker.ownedMultiTokens.push(_tokenId);}
        staker.multiToken[_tokenId].push(info);
        
        emit Staked(_user, _tokenId);
    }
    
    function unstakeERC721(uint256 tokenId) public {
        uint256 stakeTimestamp = stakers[msg.sender].token[tokenId].timestamp; 
        require(stakeTimestamp != 0,"Nft Staking System: user must be the owner of the staked nft");
        require(stakingUnlock < (block.timestamp - stakeTimestamp), "Staked token cannot be unstaked as minimum period has not elapsed");
        _unstakeERC721(tokenId);
    }

    function unstakeERC1155(uint256 tokenId, uint256 tokenIndex) public{
        ItemInfo memory stakedItem = stakers[msg.sender].multiToken[tokenId][tokenIndex];
        require(stakedItem.amount != 0 ,"Nft Staking System: user must be the owner of the staked nft");
        require(stakingUnlock < (block.timestamp - stakedItem.timestamp), "Staked token cannot be unstaked as minimum period has not elapsed");
        _unstakeERC1155(tokenId,tokenIndex);
    }

    function batchUnstakeERC721(uint256[] memory tokenIds) private{
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 stakeTimestamp = stakers[msg.sender].token[tokenIds[i]].timestamp; 
            require(stakeTimestamp != 0,"Nft Staking System: user must be the owner of the staked nft");
            require(stakingUnlock < (block.timestamp - stakeTimestamp), "Staked token cannot be unstaked as minimum period has not elapsed");
            _unstakeERC721(tokenIds[i]);
        }
    }

    function batchUnstakeERC1155(uint256[] memory tokenIds, uint256[] memory tokenIndexs) private{
        for (uint256 i = 0; i < tokenIds.length; i++) {
            
            require(stakers[msg.sender].multiToken[tokenIds[i]][tokenIndexs[i]].amount != 0 ,"Nft Staking System: user must be the owner of the staked nft");
             require(stakingUnlock < (block.timestamp - uint(stakers[msg.sender].multiToken[tokenIds[i]][tokenIndexs[i]].timestamp)), "Staked token cannot be unstaked as minimum period has not elapsed");
            _unstakeERC1155(tokenIds[i],tokenIndexs[i]);
        }
    }

    function _unstakeERC721(uint256 _tokenId) private nonReentrant  {
        // updateReward
        Staker storage staker = stakers[msg.sender];
        ItemInfo memory item = staker.token[_tokenId];
        uint256 elapsedTime = block.timestamp - uint(item.timestamp);
        uint256 stakedPeriods = elapsedTime / stakingPeriod;
        uint256 rewards =  (token * stakedPeriods) + item.bonus ;
        // claimReward;        
        if(elapsedTime>stakingMinimum && tokensClaimable == true){ 
            rewardsToken.mint(msg.sender, rewards);
            emit RewardPaid(msg.sender, rewards);
            // CALL UPDATE TOKEN METADATA
        }
        // unstake
        delete staker.token[_tokenId];
        for(uint _j = 0; _j < staker.ownedTokens.length; _j++){
            if(staker.ownedTokens[_j] == _tokenId){
                staker.ownedTokens[_j] = staker.ownedTokens[staker.ownedTokens.length-1] ;
                staker.ownedTokens.pop();
                break;
            }  
        }
        land.safeTransferFrom(address(this), msg.sender, _tokenId);
        emit Unstaked(msg.sender, _tokenId);
    }

    function _unstakeERC1155(uint256 _tokenId, uint256 _index) private nonReentrant  {
        // updateReward
        Staker storage staker = stakers[msg.sender];
        ItemInfo memory item = staker.multiToken[_tokenId][_index];
        uint256 tokenAmount = item.amount;
        uint256 elapsedTime = block.timestamp - item.timestamp;               
        uint256 stakedPeriods = (block.timestamp - item.timestamp) / stakingPeriod;
        uint256 rewards =   (item.amount * token * stakedPeriods) + item.bonus;
        // claimReward

        if(elapsedTime>stakingMinimum && tokensClaimable == true){ 
            rewardsToken.mint(msg.sender, rewards);
            emit RewardPaid(msg.sender, rewards);
            // CALL UPDATE TOKEN METADATA
        }
        // unstake
        // remove from map of token => StakedTokenInfo[] 
        staker.multiToken[_tokenId][_index] = staker.multiToken[_tokenId][staker.multiToken[_tokenId].length-1] ;
        staker.multiToken[_tokenId].pop();
        // remove from array of staked tokens
        if(staker.multiToken[_tokenId].length == 0){
            for(uint _j = 0; _j < staker.ownedMultiTokens.length; _j++){
                if(staker.ownedMultiTokens[_j] == _tokenId){
                    staker.ownedMultiTokens[_j] = staker.ownedMultiTokens[staker.ownedMultiTokens.length-1] ;
                    staker.ownedMultiTokens.pop();
                    break;
                }  
            }
        }
    
        items.safeTransferFrom(address(this), msg.sender, _tokenId, tokenAmount, "0x00 ");
        emit Unstaked(msg.sender, _tokenId, tokenAmount);
    }


    //we need this function to recieve ERC1155 NFT
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}