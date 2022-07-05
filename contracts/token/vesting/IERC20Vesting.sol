// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.0;

interface IERC20Vesting {
    /// @dev Vesting Terms for ERC tokens
    struct VestingTerms {
        /// @dev startTime for vesting
        uint256 startTime;
        /// @dev vesting Period
        uint256 period;
        /// @dev time after which tokens will be claimable, acts as a vesting cliff
        uint256 firstClaimableAt;
        /// @dev total amount of tokens to vest over period
        uint256 amount;
        /// @dev how much was claimed so far
        uint256 claimed;
    }

    /// A new vesting receiver was added.
    event VestingAdded(address indexed receiver, uint256 termsId, VestingTerms terms);

    /// An existing vesting receiver was removed.
    event VestingRemoved(address indexed receiver, uint256 termsId);

    /// An existing vesting receiver's address has changed.
    event VestingTransferred(address indexed oldReceiver, uint256 oldTermsId, address newReceiver, uint256 newTermsId);

    /// Some portion of the available amount was claimed by the vesting receiver.
    event VestingClaimed(address indexed receiver, uint256 termsId, uint256 value);

    /// @return Address of account that starts and stops vesting for different parties
    function wallet() external view returns (address);

    /// @return Address of token that is being vested
    function token() external view returns (IERC20);

    /// @dev Returns next id for vesting terms for particular user
    /// @param receiver Address of user
    /// @return id of the next terms when added to vesting
    function nextTermsId(address receiver) external view returns (uint256);

    /// @dev Returns terms on which particular reciever is getting vested tokens
    /// @param receiver Address of beneficiary
    /// @param termsId id of the vesting terms for the user
    /// @return Vesting terms of particular receiver
    function getVestingTerms(address receiver, uint256 termsId) external view returns (VestingTerms memory);

    /// @dev Adds new account for vesting
    /// @param receiver Beneficiary for vesting tokens
    /// @param terms Vesting terms for particular receiver
    function startVesting(address receiver, VestingTerms calldata terms) external;

    /// @dev Adds multiple accounts for vesting
    /// Arrays need to be of same length
    /// @param receivers Beneficiaries for vesting tokens
    /// @param terms Vesting terms for all accounts
    function startVestingBatch(address[] calldata receivers, VestingTerms[] calldata terms) external;

    /// @dev Transfers all vested tokens to the sender
    /// @param termsId Id of the vesting terms we are executing claiming for
    function claim(uint256 termsId) external;

    /// @dev Transfers a part of vested tokens to the sender
    /// @param termsId Id of the vesting terms we are executing claiming for
    /// @param value Number of tokens to claim
    ///              The special value type(uint256).max will try to claim all available tokens
    function claim(uint256 termsId, uint256 value) external;

    /// @dev Transfers vesting schedule from `msg.sender` to new address
    /// A receiver cannot have an existing vesting schedule.
    /// @param oldAddress Address for current token receiver
    /// @param oldTermsId Id of the terms we are transfering
    /// @param newAddress Address for new token receiver
    function transferVesting(address oldAddress, uint256 oldTermsId, address newAddress) external;

    /// @dev Stops vesting for receiver and sends unvested tokens back to wallet
    /// Any earned claimable amount is still claimable through `claim()`.
    /// Note that the account cannot be used again as the vesting receiver.
    /// @param receiver Address of account for which we are stopping vesting
    /// @param termsId id of the terms we are stopping vesting for
    function stopVesting(address receiver, uint256 termsId) external;

    /// @dev Calculates the maximum amount of vested tokens that can be claimed for particular address
    /// @param receiver Address of token receiver
    /// @param termsId id of the vesting terms we are checking claims for
    /// @return Number of vested tokens one can claim
    function claimable(address receiver, uint256 termsId) external view returns (uint256);
}
