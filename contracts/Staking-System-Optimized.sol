// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "hardhat/console.sol";

interface IRewardToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract StakingSystemRequired is AccessControl, ERC721Holder, ReentrancyGuard, Pausable  {
    IRewardToken public rewardsToken;
    IERC721 public land;
    IERC1155 public items;

    uint256 public stakingPeriod = 1 minutes;
    uint256 public stakingMinimum = 0 days;
    uint256 public stakingUnlock = 0 days;
    uint256 constant token = 10e18;
    
    bool public tokensClaimable;
    bool initialised;
    

    struct ItemInfo {
        uint256 amount;
        uint256 timestamp;
    }
    
    struct Staker {
        mapping(uint256 => ItemInfo[]) multiToken;
        mapping(uint256 => ItemInfo) token;

        uint256[] ownedMultiTokens;
        uint256[] ownedTokens;
        uint8 claimReward;
    }

    constructor(IERC721 _land, IERC1155 _items, IRewardToken _rewardsToken) {
        items = _items;
        land = _land;
        rewardsToken = _rewardsToken;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
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

    function initStaking() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!initialised, "Already initialised");
        initialised = true;
    }

    function setTokensClaimable(bool _enabled) public onlyRole(DEFAULT_ADMIN_ROLE) {
        tokensClaimable = _enabled;
        emit ClaimableStatusUpdated(_enabled);
    }

    function setMinimumStakingPeriod(uint256 _period) public onlyRole(DEFAULT_ADMIN_ROLE) {
        stakingMinimum = _period;
    }

    function setUnlockPeriod(uint256 _period) public onlyRole(DEFAULT_ADMIN_ROLE) {
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

    function stakeERC721(uint256 tokenId) public {
        require(initialised, "Staking System: the staking has not started");
        require(land.ownerOf(tokenId) == msg.sender , "Account doesnt own token");
        _stakeERC721(msg.sender, tokenId);
    }

    
    function stakeERC1155(uint256 tokenId, uint256 tokenAmount ) public  {
        require(initialised, "Staking System: the staking has not started");
        require(items.balanceOf(msg.sender, tokenId) > 0, "Account have less token");
        _stakeERC1155(msg.sender, tokenId, tokenAmount);
    }

    function batchStakeERC721(uint256[] memory tokenIds) public {
        require(initialised, "Staking System: the staking has not started");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(land.ownerOf(tokenIds[i]) == msg.sender , "Account doesnt own token");
            _stakeERC721(msg.sender, tokenIds[i]);
        }
    }

    function batchStakeERC1155(uint256[] memory tokenIds, uint256[] memory tokenAmounts) public {
        require(initialised, "Staking System: the staking has not started");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(items.balanceOf(msg.sender, tokenIds[i]) > 0, "Account have less token");
            _stakeERC1155(msg.sender, tokenIds[i], tokenAmounts[i]);
        }
    }

    function _stakeERC721(address _user, uint256 _tokenId) private nonReentrant{
        land.safeTransferFrom(_user, address(this), _tokenId);
        Staker storage staker = stakers[_user];

        ItemInfo memory info = ItemInfo(1,block.timestamp);
        staker.token[_tokenId] = info;
        staker.ownedTokens.push(_tokenId);

        emit Staked(_user, _tokenId);
    }

    function _stakeERC1155(address _user, uint256 _tokenId, uint256 _tokenAmount) private nonReentrant {
        items.safeTransferFrom(_user, address(this), _tokenId, _tokenAmount, "");
        Staker storage staker = stakers[_user];
        ItemInfo memory info = ItemInfo(_tokenAmount,block.timestamp);
        if(staker.multiToken[_tokenId].length == 0) {staker.ownedMultiTokens.push(_tokenId);}
        staker.multiToken[_tokenId].push(info);
        emit Staked(_user, _tokenId);
    }
    
    function unstakeERC721(uint256 tokenId) public {
        require(stakers[msg.sender].token[tokenId].timestamp != 0,"Nft Staking System: user must be the owner of the staked nft");
        require(stakingUnlock < (block.timestamp - uint(stakers[msg.sender].token[tokenId].timestamp)), "Staked token cannot be unstaked as minimum period has not elapsed");
        _unstakeERC721(tokenId);
        
    }

    function unstakeERC1155(uint256 tokenId, uint256 tokenIndex) public{
        require(stakers[msg.sender].multiToken[tokenId][tokenIndex].amount != 0 ,"Nft Staking System: user must be the owner of the staked nft");
        require(stakingUnlock < (block.timestamp - uint(stakers[msg.sender].multiToken[tokenId][tokenIndex].timestamp)), "Staked token cannot be unstaked as minimum period has not elapsed");
        _unstakeERC1155(tokenId,tokenIndex);
    }

    function batchUnstakeERC721(uint256[] memory tokenIds) private{
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(stakers[msg.sender].token[i].timestamp != 0,"Nft Staking System: user must be the owner of the staked nft");
            require(stakingUnlock < (block.timestamp - uint(stakers[msg.sender].token[tokenIds[i]].timestamp)), "Staked token cannot be unstaked as minimum period has not elapsed");
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
        uint256[] memory ownedTokens =  staker.ownedTokens;
        uint256 elapsedTime = block.timestamp - staker.token[_tokenId].timestamp;
        uint256 stakedPeriods = elapsedTime / stakingPeriod;
        uint256 rewards =  token * stakedPeriods;
        uint256 length = ownedTokens.length;
        // claimReward;        
        if(elapsedTime>stakingMinimum && tokensClaimable == true){ 
            rewardsToken.mint(msg.sender, rewards);
            emit RewardPaid(msg.sender, rewards);
            // CALL UPDATE TOKEN METADATA
        }
        // unstake
        delete staker.token[_tokenId];
        for(uint _j = 0; _j < length; _j++){
            if(ownedTokens[_j] == _tokenId){
                staker.ownedTokens[_j] = ownedTokens[ownedTokens.length-1] ;
                staker.ownedTokens.pop();
                break;
            }  
        }
        // land.incrementTokenURI(_tokenId);
        land.safeTransferFrom(address(this), msg.sender, _tokenId);
        emit Unstaked(msg.sender, _tokenId);
    }

    function _unstakeERC1155(uint256 _tokenId, uint256 _index) private nonReentrant  {
        // updateReward
        ItemInfo[] storage tokens = stakers[msg.sender].multiToken[_tokenId];
        ItemInfo memory item = tokens[_index];
        uint256[] memory tokenIDs = stakers[msg.sender].ownedMultiTokens;
        uint256 tokenAmount = item.amount;
        uint256 elapsedTime = block.timestamp - item.timestamp;               
        uint256 stakedPeriods = (block.timestamp - item.timestamp) / stakingPeriod;
        uint256 rewards =   item.amount * token * stakedPeriods;
        uint256 length = tokenIDs.length;

        if(elapsedTime>stakingMinimum && tokensClaimable == true){ // claimReward
            rewardsToken.mint(msg.sender, rewards);
            emit RewardPaid(msg.sender, rewards);
            // CALL UPDATE TOKEN METADATA
        }
        // unstake
        tokens[_index] = tokens[tokens.length-1] ; // remove from map of token => StakedTokenInfo[] 
        tokens.pop();
        
        if(tokens.length == 0){ // remove from array of staked tokens
            for(uint _j = 0; _j < length; _j++){
                if(tokenIDs[_j] == _tokenId){
                    stakers[msg.sender].ownedMultiTokens[_j] = tokenIDs[tokenIDs.length-1] ;
                    stakers[msg.sender].ownedMultiTokens.pop();
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