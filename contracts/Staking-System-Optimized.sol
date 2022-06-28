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

    uint256 public stakingPeriod = 1 seconds;
    uint256 public stakingMinimum = 0 days;
    uint256 public stakingUnlock = 0 days;
    uint256 constant token = 10e18;
    
    bool public tokensClaimable;
    bool initialised;
    

    struct ItemInfo {
        uint16 amount;
        uint256 timestamp;
    }
    
    struct Staker {
        mapping(uint256 => ItemInfo[]) multiToken;
        mapping(uint256 => ItemInfo) token;

        uint256[] ownedMultiTokens;
        uint256[] ownedTokens;
        bool claimed;
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
    event Staked721(address owner, uint256 id);
    event Staked1155(address owner, uint256 id, uint16 amount);

    /// @notice event emitted when a user has unstaked a nft
    event Unstaked721(address owner, uint256 id);
    event Unstaked1155(address owner, uint256 id, uint16 amount);

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

    
    function stakeERC1155(uint256 tokenId, uint16  tokenAmount ) public  {
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

    function batchStakeERC1155(uint256[] memory tokenIds, uint16[] memory tokenAmounts) public {
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

        emit Staked721(_user, _tokenId);
    }

    function _stakeERC1155(address _user, uint256 _tokenId, uint16  _tokenAmount) private nonReentrant {
        items.safeTransferFrom(_user, address(this), _tokenId, _tokenAmount, "");
        Staker storage staker = stakers[_user];
        ItemInfo memory info = ItemInfo(_tokenAmount,block.timestamp);
        if(staker.multiToken[_tokenId].length == 0) {staker.ownedMultiTokens.push(_tokenId);}
        staker.multiToken[_tokenId].push(info);
        emit Staked1155(_user, _tokenId,_tokenAmount);
    }
    
    function unstakeERC721(uint256 tokenId) public {
        require(stakers[msg.sender].token[tokenId].timestamp != 0,"Nft Staking System: user must be the owner of the staked nft");
        require(stakingUnlock < (block.timestamp - uint(stakers[msg.sender].token[tokenId].timestamp)), "Staked token cannot be unstaked as minimum period has not elapsed");
        _unstakeERC721(tokenId);
        
    }

    function unstakeERC1155(uint256 tokenId, uint256 tokenIndex) public{
        require(stakers[msg.sender].multiToken[tokenId].length != 0 ,"Nft Staking System: user has no nfts of this type staked");
        require(stakers[msg.sender].multiToken[tokenId][tokenIndex].amount != 0 ,"Nft Staking System: user must be the owner of the staked nft");

        uint256 elapsedTime = block.timestamp - uint(stakers[msg.sender].multiToken[tokenId][tokenIndex].timestamp);
        require(stakingUnlock < elapsedTime, "Staked token cannot be unstaked as minimum period has not elapsed");
        _unstakeERC1155(tokenId,tokenIndex,elapsedTime);
    }

    function batchUnstakeERC721(uint256[] memory tokenIds) public{
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(stakers[msg.sender].token[tokenIds[i]].timestamp != 0,"Nft Staking System: user must be the owner of the staked nft");
            require(stakingUnlock < (block.timestamp - uint(stakers[msg.sender].token[tokenIds[i]].timestamp)), "Staked token cannot be unstaked as minimum period has not elapsed");
            _unstakeERC721(tokenIds[i]);
        }
    }

    function batchUnstakeERC1155(uint256[] memory tokenIds, uint256[] memory tokenIndexs) public{
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(stakers[msg.sender].multiToken[tokenIds[i]].length != 0 ,"Nft Staking System: user has no nfts of this type staked");
            require(tokenIndexs[i] < stakers[msg.sender].multiToken[tokenIds[i]].length ,"Nft Staking System: out of bounds token index");
            require(stakers[msg.sender].multiToken[tokenIds[i]][tokenIndexs[i]].amount != 0 ,"Nft Staking System: user must be the owner of the staked nft");
            
            uint256 elapsedTime = block.timestamp - uint(stakers[msg.sender].multiToken[tokenIds[i]][tokenIndexs[i]].timestamp);
            require(stakingUnlock < elapsedTime, "Staked token cannot be unstaked as minimum period has not elapsed");
            _unstakeERC1155(tokenIds[i],tokenIndexs[i], elapsedTime);
        }
    }

    function _unstakeERC721(uint256 _tokenId) private nonReentrant  {
        // updateReward
        Staker storage staker = stakers[msg.sender];
        uint256[] memory ownedTokens =  staker.ownedTokens;
        uint256 elapsedTime = block.timestamp - staker.token[_tokenId].timestamp;
        
        // claimReward;        
        if(elapsedTime>stakingMinimum && tokensClaimable == true){ 
            uint256 stakedPeriods = (elapsedTime) / stakingPeriod;
            uint256 rewards =  token * stakedPeriods;
            rewardsToken.mint(msg.sender, rewards);
            emit RewardPaid(msg.sender, rewards);
            // CALL UPDATE TOKEN METADATA
        }
        // unstake
        delete staker.token[_tokenId];
        for(uint _j = 0; _j <  ownedTokens.length; _j++){
            if(ownedTokens[_j] == _tokenId){
                ownedTokens[_j] = ownedTokens[ownedTokens.length-1] ;
                delete ownedTokens[ownedTokens.length-1];
                break;
            }  
        }
        staker.ownedTokens = ownedTokens;
        // land.incrementTokenURI(_tokenId);
        land.safeTransferFrom(address(this), msg.sender, _tokenId);
        emit Unstaked721(msg.sender, _tokenId);
    }

    function _unstakeERC1155(uint256 _tokenId, uint256 _index, uint256 _elapsedTime) private nonReentrant  {
        // updateReward
        Staker storage staker = stakers[msg.sender];
        ItemInfo memory item = staker.multiToken[_tokenId][_index];
        uint16  tokenAmount = item.amount;
        
        if(_elapsedTime>stakingMinimum && tokensClaimable == true){ 
            uint256 stakedPeriods = (block.timestamp - item.timestamp) / stakingPeriod;
            uint256 rewards =   (item.amount * token * stakedPeriods);
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
        emit Unstaked1155(msg.sender, _tokenId, tokenAmount);
    }


    //we need this function to recieve ERC1155 NFT
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}