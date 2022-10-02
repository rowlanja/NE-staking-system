// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IRewardToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract StakingSystemRequired is Ownable, ERC721Holder, ReentrancyGuard, Pausable {
    IRewardToken public rewardsToken;
    IERC721 public land;
    IERC1155 public items;

    uint256 public stakingPeriod = 1 seconds;
    uint256 public stakingMinimum = 0 days;
    uint256 public stakingUnlock = 0 days;
    uint256 constant token = 10e18;

    bool public tokensClaimable;

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

    constructor(
        IERC721 _land,
        IERC1155 _items,
        IRewardToken _rewardsToken
    ) {
        land = _land;
        items = _items;
        rewardsToken = _rewardsToken;
    }

    /// @notice mapping of a staker to its wallet
    mapping(address => Staker) public stakers;

    /// @notice event emitted when a user has staked a nft
    event Staked721(address owner, uint256 id);
    event Staked1155(address owner, uint256 id, uint16 amount);
    /// @notice event emitted when a user has staked a batch of nft
    event StakedBatch1155(address owner, uint256[] ids, uint256[] amounts);

    /// @notice event emitted when a user has unstaked a nft
    event Unstaked721(address owner, uint256 id);
    event Unstaked1155(address owner, uint256 id, uint16 amount);
    /// @notice event emitted when a user has unstaked a batch of nft
    event UnstakedBatch1155(address owner, uint256[] ids, uint256[] amounts);

    /// @notice event emitted when a user claims reward
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice Allows reward tokens to be claimed
    event ClaimableStatusUpdated(bool status);

    function setPause() external onlyOwner {
        if (paused() == true) {
            _unpause();
        } else {
            _pause();
        }
    }

    function setTokensClaimable(bool _enabled) external onlyOwner {
        tokensClaimable = _enabled;
        emit ClaimableStatusUpdated(_enabled);
    }

    function setMinimumStakingPeriod(uint256 _period) external onlyOwner {
        stakingMinimum = _period;
    }

    function setUnlockPeriod(uint256 _period) external onlyOwner {
        stakingUnlock = _period;
    }

    function GetStakedERC721(address _user, uint256 _tokenId)
        external
        view
        returns (ItemInfo memory)
    {
        return stakers[_user].token[_tokenId];
    }

    function GetStakedERC1155(address _user, uint256 _tokenId)
        external
        view
        returns (ItemInfo[] memory)
    {
        return stakers[_user].multiToken[_tokenId];
    }

    function GetAllStakedERC721(address _user)
        external
        view
        returns (uint256[] memory tokenIds)
    {
        return stakers[_user].ownedTokens;
    }

    function GetAllStakedERC1155(address _user)
        external
        view
        returns (uint256[] memory tokenIds)
    {
        return stakers[_user].ownedMultiTokens;
    }

    function stakeERC721(uint256 tokenId) external whenNotPaused {
        require(
            land.ownerOf(tokenId) == msg.sender,
            "Account doesnt own token"
        );
        _stakeERC721(msg.sender, tokenId);
    }

    function stakeERC1155(uint256 tokenId, uint16 tokenAmount)
        external
        whenNotPaused
    {
        require(tokenAmount > 0, "Min amount 1");
        require(
            items.balanceOf(msg.sender, tokenId) > 0,
            "Account have less token"
        );
        _stakeERC1155(msg.sender, tokenId, tokenAmount);
    }

    function batchStakeERC721(uint256[] memory tokenIds)
        external
        whenNotPaused
    {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                land.ownerOf(tokenIds[i]) == msg.sender,
                "Account doesnt own token"
            );
            _stakeERC721(msg.sender, tokenIds[i]);
        }
    }

    function batchStakeERC1155(
        uint256[] memory tokenIds,
        uint256[] memory tokenAmounts
    ) external whenNotPaused {
        require(
            tokenIds.length == tokenAmounts.length,
            "Ids and amounts length mismatch"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(tokenAmounts[i] > 0, "Min amount 1");
            require(
                items.balanceOf(msg.sender, tokenIds[i]) > 0,
                "Account have less token"
            );
        }
        _batchStakeERC1155(msg.sender, tokenIds, tokenAmounts);
    }

    function _stakeERC721(address _user, uint256 _tokenId)
        private
        nonReentrant
    {
        land.safeTransferFrom(_user, address(this), _tokenId);
        Staker storage staker = stakers[_user];

        ItemInfo memory info = ItemInfo(1, block.timestamp);
        staker.token[_tokenId] = info;
        staker.ownedTokens.push(_tokenId);

        emit Staked721(_user, _tokenId);
    }

    function _stakeERC1155(
        address _user,
        uint256 _tokenId,
        uint16 _tokenAmount
    ) private nonReentrant {
        items.safeTransferFrom(
            _user,
            address(this),
            _tokenId,
            _tokenAmount,
            ""
        );
        Staker storage staker = stakers[_user];
        ItemInfo memory info = ItemInfo(_tokenAmount, block.timestamp);
        if (staker.multiToken[_tokenId].length == 0) {
            staker.ownedMultiTokens.push(_tokenId);
        }
        staker.multiToken[_tokenId].push(info);
        emit Staked1155(_user, _tokenId, _tokenAmount);
    }

    function _batchStakeERC1155(
        address _user,
        uint256[] memory _tokenIds,
        uint256[] memory _tokenAmounts
    ) private nonReentrant {
        items.safeBatchTransferFrom(
            _user,
            address(this),
            _tokenIds,
            _tokenAmounts,
            ""
        );
        Staker storage staker = stakers[_user];

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            ItemInfo memory info = ItemInfo(
                uint16(_tokenAmounts[i]),
                block.timestamp
            );
            if (staker.multiToken[_tokenIds[i]].length == 0) {
                staker.ownedMultiTokens.push(_tokenIds[i]);
            }
            staker.multiToken[_tokenIds[i]].push(info);
        }

        emit StakedBatch1155(_user, _tokenIds, _tokenAmounts);
    }

    function unstakeERC721(uint256 tokenId) external {
        require(
            stakers[msg.sender].token[tokenId].timestamp != 0,
            "Nft Staking System: user must be the owner of the staked nft"
        );
        require(
            stakingUnlock <
                (block.timestamp -
                    uint256(stakers[msg.sender].token[tokenId].timestamp)),
            "Staked token cannot be unstaked as minimum period has not elapsed"
        );
        _unstakeERC721(tokenId);
    }

    function unstakeERC1155(uint256 tokenId, uint256 tokenIndex) external {
        require(
            stakers[msg.sender].multiToken[tokenId].length != 0,
            "Nft Staking System: user has no nfts of this type staked"
        );
        require(
            stakers[msg.sender].multiToken[tokenId][tokenIndex].amount != 0,
            "Nft Staking System: user must be the owner of the staked nft"
        );

        uint256 elapsedTime = block.timestamp -
            uint256(
                stakers[msg.sender].multiToken[tokenId][tokenIndex].timestamp
            );
        require(
            stakingUnlock < elapsedTime,
            "Staked token cannot be unstaked as minimum period has not elapsed"
        );
        _unstakeERC1155(tokenId, tokenIndex, elapsedTime);
    }

    function batchUnstakeERC721(uint256[] memory tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                stakers[msg.sender].token[tokenIds[i]].timestamp != 0,
                "Nft Staking System: user must be the owner of the staked nft"
            );
            require(
                stakingUnlock <
                    (block.timestamp -
                        uint256(
                            stakers[msg.sender].token[tokenIds[i]].timestamp
                        )),
                "Staked token cannot be unstaked as minimum period has not elapsed"
            );
            _unstakeERC721(tokenIds[i]);
        }
    }

    function batchUnstakeERC1155(
        uint256[] memory tokenIds,
        uint256[] memory tokenIndexes
    ) external {
        require(
            tokenIds.length == tokenIndexes.length,
            "Ids and indexes length mismatch"
        );
        uint256 elapsedTime;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                stakers[msg.sender].multiToken[tokenIds[i]].length != 0,
                "Nft Staking System: user has no nfts of this type staked"
            );
            require(
                tokenIndexes[i] <
                    stakers[msg.sender].multiToken[tokenIds[i]].length,
                "Nft Staking System: out of bounds token index"
            );

            elapsedTime =
                block.timestamp -
                uint256(
                    stakers[msg.sender]
                    .multiToken[tokenIds[i]][tokenIndexes[i]].timestamp
                );
            require(
                stakingUnlock < elapsedTime,
                "Staked token cannot be unstaked as minimum period has not elapsed"
            );
        }
        _batchUnstakeERC1155(tokenIds, tokenIndexes, elapsedTime);
    }

    function _unstakeERC721(uint256 _tokenId) private nonReentrant {
        // updateReward
        Staker storage staker = stakers[msg.sender];
        uint256 elapsedTime = block.timestamp -
            staker.token[_tokenId].timestamp;

        // claimReward
        if (elapsedTime > stakingMinimum && tokensClaimable == true) {
            uint256 stakedPeriods = (elapsedTime) / stakingPeriod;
            uint256 rewards = token * stakedPeriods;
            rewardsToken.mint(msg.sender, rewards);
            emit RewardPaid(msg.sender, rewards);
        }
        // unstake
        delete staker.token[_tokenId];
        for (uint256 _j = 0; _j < staker.ownedTokens.length; _j++) {
            if (staker.ownedTokens[_j] == _tokenId) {
                staker.ownedTokens[_j] = staker.ownedTokens[
                    staker.ownedTokens.length - 1
                ];

                staker.ownedTokens.pop();
                break;
            }
        }
        land.safeTransferFrom(address(this), msg.sender, _tokenId);
        emit Unstaked721(msg.sender, _tokenId);
    }

    function _unstakeERC1155(
        uint256 _tokenId,
        uint256 _index,
        uint256 _elapsedTime
    ) private nonReentrant {
        // updateReward
        Staker storage staker = stakers[msg.sender];
        ItemInfo memory item = staker.multiToken[_tokenId][_index];
        uint16 tokenAmount = item.amount;

        if (_elapsedTime > stakingMinimum && tokensClaimable == true) {
            uint256 stakedPeriods = (block.timestamp - item.timestamp) /
                stakingPeriod;
            uint256 rewards = (item.amount * token * stakedPeriods);
            rewardsToken.mint(msg.sender, rewards);
            emit RewardPaid(msg.sender, rewards);
        }
        // unstake
        // remove from map of token => StakedTokenInfo[]
        staker.multiToken[_tokenId][_index] = staker.multiToken[_tokenId][
            staker.multiToken[_tokenId].length - 1
        ];
        staker.multiToken[_tokenId].pop();
        // remove from array of staked tokens
        if (staker.multiToken[_tokenId].length == 0) {
            for (uint256 _j = 0; _j < staker.ownedMultiTokens.length; _j++) {
                if (staker.ownedMultiTokens[_j] == _tokenId) {
                    staker.ownedMultiTokens[_j] = staker.ownedMultiTokens[
                        staker.ownedMultiTokens.length - 1
                    ];
                    staker.ownedMultiTokens.pop();
                    break;
                }
            }
        }

        items.safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            tokenAmount,
            ""
        );
        emit Unstaked1155(msg.sender, _tokenId, tokenAmount);
    }

    function _batchUnstakeERC1155(
        uint256[] memory _tokenIds,
        uint256[] memory _tokenIndexes,
        uint256 _elapsedTime
    ) private nonReentrant {
        Staker storage staker = stakers[msg.sender];
        uint256[] memory tokenAmounts = new uint256[](_tokenIds.length);
        uint256 rewards;
        uint256 stakedPeriods;
        ItemInfo memory item;

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            tokenAmounts[i] = staker
            .multiToken[tokenId][_tokenIndexes[i]].amount;
            item = staker.multiToken[tokenId][_tokenIndexes[i]];

            if (_elapsedTime > stakingMinimum && tokensClaimable == true) {
                stakedPeriods =
                    (block.timestamp - item.timestamp) /
                    stakingPeriod;
                rewards += (item.amount * token * stakedPeriods);
            }

            staker.multiToken[tokenId][_tokenIndexes[i]] = staker.multiToken[
                tokenId
            ][staker.multiToken[tokenId].length - 1];
            staker.multiToken[tokenId].pop();

            if (staker.multiToken[tokenId].length == 0) {
                for (
                    uint256 _j = 0;
                    _j < staker.ownedMultiTokens.length;
                    _j++
                ) {
                    if (staker.ownedMultiTokens[_j] == tokenId) {
                        staker.ownedMultiTokens[_j] = staker.ownedMultiTokens[
                            staker.ownedMultiTokens.length - 1
                        ];
                        staker.ownedMultiTokens.pop();
                        break;
                    }
                }
            }
        }
        items.safeBatchTransferFrom(
            address(this),
            msg.sender,
            _tokenIds,
            tokenAmounts,
            ""
        );
        emit UnstakedBatch1155(msg.sender, _tokenIds, tokenAmounts);
        if (rewards > 0) {
            rewardsToken.mint(msg.sender, rewards);
            emit RewardPaid(msg.sender, rewards);
        }
    }

    // We need these functions to receive ERC1155 NFT
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
