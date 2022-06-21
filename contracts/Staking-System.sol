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

contract StakingSystem is Ownable, ERC721Holder, ReentrancyGuard, Pausable  {
    IRewardToken public rewardsToken;
    IERC721 public land;
    IERC1155 public items;

    uint256 public stakedTotal;
    uint256 public stakingStartTime;
    uint256 constant stakingPeriod = 1 seconds;
    uint256 constant stakingMinimum = 0 days;
    uint256 constant token = 10e18;
    
    struct ItemInfo {
        uint256 amount;
        uint256 timestamp;
        uint256 rewards;
    }
    
    struct Staker {
        mapping(uint256 => ItemInfo) items;
        mapping(uint256 => ItemInfo) lands;

        uint256[] ownedItems;
        uint256[] ownedLands;
        uint256 claimReward;
    }

    constructor(IERC721 _land, IERC1155 _items, IRewardToken _rewardsToken) {
        items = _items;
        land = _land;
        rewardsToken = _rewardsToken;
    }

    /// @notice mapping of a staker to its wallet
    mapping(address => Staker) public stakers;

    bool public tokensClaimable;
    bool initialised;

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
        //needs access control
        require(!initialised, "Already initialised");
        stakingStartTime = block.timestamp;
        initialised = true;
    }

    function setTokensClaimable(bool _enabled) public onlyOwner {
        tokensClaimable = _enabled;
        emit ClaimableStatusUpdated(_enabled);
    }


    function getStakedItems(address _user)
        public
        view
        returns (uint256[] memory tokenIds)
    {
        return stakers[_user].ownedItems;
    }

    function getStakedLands(address _user)
        public
        view
        returns (uint256[] memory tokenIds)
    {
        return stakers[_user].ownedLands;
    }

    function stake(uint256 tokenId) public nonReentrant {
        require(initialised, "Staking System: the staking has not started");
        require(land.ownerOf(tokenId) == msg.sender , "Account doesnt own token");
        _stakeitems(msg.sender, tokenId);
    }

    
    function stake(uint256 tokenId, uint256 tokenAmount ) public nonReentrant  {
        require(initialised, "Staking System: the staking has not started");
        require(items.balanceOf(msg.sender, tokenId) > 0, "Account have less token");
        require(stakers[msg.sender].items[tokenId].amount > 0, "Already staked item of same type, please unstake staked item and restake both items"); // have to clean this up
        _stakeitems(msg.sender, tokenId, tokenAmount);
    }

    function stakeBatchItems(uint256[] memory tokenIds) public {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _stakeitems(msg.sender, tokenIds[i]);
        }
    }

    function stakeBatchItems(uint256[] memory tokenIds, uint256[] memory tokenAmounts) public {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _stakeitems(msg.sender, tokenIds[i], tokenAmounts[i]);
        }
    }


    function _stakeitems(address _user, uint256 _tokenId) internal {
        land.safeTransferFrom(_user, address(this), _tokenId);
        Staker storage staker = stakers[_user];

        ItemInfo memory info = ItemInfo(1,block.timestamp,0);
        staker.lands[_tokenId] = info;
        staker.ownedLands.push(_tokenId);

        emit Staked(_user, _tokenId);
        stakedTotal++;
    }

    function _stakeitems(address _user, uint256 _tokenId, uint256 _tokenAmount) internal {
        items.safeTransferFrom(_user, address(this), _tokenId, _tokenAmount, "");
        Staker storage staker = stakers[_user];

        ItemInfo memory info = ItemInfo(_tokenAmount,block.timestamp,0);
        staker.items[_tokenId] = info;
        staker.ownedItems.push(_tokenId);

        emit Staked(_user, _tokenId);
        stakedTotal++;
    }
    
    function getStakedItemsCount(address _user, uint256 _tokenId) public returns(uint256) {
        Staker storage staker = stakers[_user];
        return staker.items[_tokenId].amount;
    }

    function unstakeBatch(uint256[] memory tokenIds) private{
        for (uint256 i = 0; i < tokenIds.length; i++) {
            unstake(tokenIds[i]);
        }
    }

    function unstakeBatch(uint256[] memory tokenIds, uint256[] memory tokenAmounts) private{
        for (uint256 i = 0; i < tokenIds.length; i++) {
            unstake(tokenIds[i], tokenAmounts[i]);
        }
    }

    function unstake(uint256 _tokenId) public nonReentrant  {
        require(stakers[msg.sender].lands[_tokenId].amount > 0,"Nft Staking System: user must be the owner of the staked nft");
        updateReward(msg.sender, _tokenId);
        claimReward(msg.sender, _tokenId);
        _unstake(msg.sender, _tokenId);
    }

    function unstake(uint256 _tokenId, uint256 _tokenAmount) public nonReentrant  {
        require(stakers[msg.sender].items[_tokenId].amount == 0 ,"Nft Staking System: user must be the owner of the staked nft");
        require(stakers[msg.sender].items[_tokenId].amount >= _tokenAmount ,"Nft Staking System: user has not staked correct amount of NFT's");

        updateReward(msg.sender, _tokenId, _tokenAmount);
        claimReward(msg.sender, _tokenId, _tokenAmount);
        _unstake(msg.sender, _tokenId, _tokenAmount);
    }

    function _unstake(address _user, uint256 _tokenId) internal {
        Staker storage staker = stakers[_user];
        delete staker.lands[_tokenId];
        land.safeTransferFrom(address(this), _user, _tokenId);

        for(uint _j = 0; _j < staker.ownedLands.length; _j++){
            if(staker.ownedLands[_j] == _tokenId){
                staker.ownedLands[_j] = staker.ownedLands[staker.ownedLands.length-1] ;
                staker.ownedLands.pop;
                break;
            }  
        }

        emit Unstaked(_user, _tokenId);
        stakedTotal--;
    }


    function _unstake(address _user, uint256 _tokenId, uint256 _tokenAmount) internal {
        Staker storage staker = stakers[_user];
        if(staker.items[_tokenId].amount - _tokenAmount == 0) {
            delete staker.items[_tokenId];
            for(uint _j = 0; _j < staker.ownedItems.length; _j++){
                if(staker.ownedItems[_j] == _tokenId){
                    staker.ownedItems[_j] = staker.ownedItems[staker.ownedItems.length-1] ;
                    staker.ownedItems.pop;
                    break;
                }  
            }
        }
        else { staker.items[_tokenId].amount -= _tokenAmount; }
        items.safeTransferFrom(address(this), _user, _tokenId, _tokenAmount, "0x00 ");

        emit Unstaked(_user, _tokenId, _tokenAmount);
        stakedTotal--;
    }


    function claimReward(address _user, uint256 tokenID) private  {
        require(tokensClaimable == true, "Tokens cannnot be claimed yet");
        Staker storage staker = stakers[_user];
        uint256 elapsedTime = block.timestamp - uint(staker.items[tokenID].timestamp);
        if(elapsedTime<stakingMinimum){ console.log("Minimum Staking Period not elapsed, rewards null");}
        else {
            rewardsToken.mint(_user, staker.lands[tokenID].rewards);
            emit RewardPaid(_user, staker.lands[tokenID].rewards);
            staker.lands[tokenID].rewards=0;
        }
    }

    function claimReward(address _user, uint256 tokenID,uint256 tokenAmount) private  {
        require(tokensClaimable == true, "Tokens cannnot be claimed yet");
        Staker storage staker = stakers[_user];
        uint256 elapsedTime = block.timestamp - uint(staker.items[tokenID].timestamp);   
        if(elapsedTime<stakingMinimum){ console.log("Minimum Staking Period not elapsed, rewards null");}
        else {
            rewardsToken.mint(_user, staker.items[tokenID].rewards);
            emit RewardPaid(_user, staker.items[tokenID].rewards);
            staker.items[tokenID].rewards=0;
        }
    }

    function updateReward(address _user, uint256 tokenID) private  {
        Staker storage staker = stakers[_user];
        uint256 stakedPeriods = (block.timestamp - uint(staker.lands[tokenID].timestamp)) / stakingPeriod;
            
        staker.lands[tokenID].rewards =  token * stakedPeriods;
        console.logUint(staker.lands[tokenID].rewards);
        
    }

    function updateReward(address _user, uint256 tokenID, uint256 tokenAmount) private  {
        Staker storage staker = stakers[_user];
        uint256 stakedPeriods = (block.timestamp - uint(staker.items[tokenID].timestamp)) / stakingPeriod;
            
        staker.items[tokenID].rewards =  token * staker.items[tokenID].amount * stakedPeriods;
        console.logUint(staker.items[tokenID].rewards);
    }

    //we need this function to recieve ERC1155 NFT
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}