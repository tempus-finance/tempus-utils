// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IERC20Vesting.sol";

contract ERC20Vesting is IERC20Vesting {
    using SafeERC20 for IERC20;

    address public immutable override wallet;
    IERC20 public immutable override token;
    mapping(address => uint256) public nextTermsId;
    mapping(address => mapping(uint256 => VestingTerms)) private vestingTerms;

    modifier onlyWallet() {
        require(msg.sender == wallet, "Only wallet is allowed to proceed");
        _;
    }

    /// @param _token Address of ERC20 token associated with this vesting contract
    /// @param _wallet Address of account that starts and stops vesting for different parties
    constructor(IERC20 _token, address _wallet) {
        require(address(_token) != address(0), "Token cannot be 0.");
        require(address(_wallet) != address(0), "Wallet cannot be 0.");

        token = _token;
        wallet = _wallet;
    }

    function getVestingTerms(address receiver, uint256 termsId) external view override returns (VestingTerms memory) {
        return vestingTerms[receiver][termsId];
    }

    function startVesting(address receiver, VestingTerms calldata terms) public override onlyWallet {
        require(receiver != address(0), "Receiver cannot be 0.");
        require(terms.amount > 0, "Amount must be > 0.");
        require(terms.startTime != 0, "Start time must be set.");
        require(terms.firstClaimableAt >= terms.startTime, "firstClaimableAt should be >= startTime.");
        require(terms.firstClaimableAt <= (terms.startTime + terms.period), "firstClaimableAt should be <= end time.");
        require(terms.period > 0, "Period must be set.");
        require(terms.claimed == 0, "Can not start vesting with already claimed tokens.");
        assert(isScheduleValid(terms));

        uint256 currentId = nextTermsId[receiver]++;
        vestingTerms[receiver][currentId] = terms;
        token.safeTransferFrom(wallet, address(this), terms.amount);

        emit VestingAdded(receiver, currentId, terms);
    }

    function startVestingBatch(address[] calldata receivers, VestingTerms[] calldata terms)
        external
        override
        onlyWallet
    {
        require(receivers.length > 0, "Zero receivers.");
        require(receivers.length == terms.length, "Terms and receivers must have same length.");

        for (uint256 i = 0; i < receivers.length; i++) {
            startVesting(receivers[i], terms[i]);
        }
    }

    function claim(uint256 termsId) external override {
        claim(termsId, type(uint256).max);
    }

    function claim(uint256 termsId, uint256 value) public override {
        require(value > 0, "Claiming 0 tokens.");
        VestingTerms memory terms = vestingTerms[msg.sender][termsId];
        require(isScheduleValid(terms), "No vesting data for sender.");

        uint256 claimableTokens = _claimable(terms);
        if (value == type(uint256).max) {
            value = claimableTokens;
        } else {
            require(value <= claimableTokens, "Claiming amount exceeds allowed tokens.");
        }

        vestingTerms[msg.sender][termsId].claimed += value;
        token.safeTransfer(msg.sender, value);

        emit VestingClaimed(msg.sender, termsId, value);
    }

    function transferVesting(address oldAddress, uint256 oldTermsId, address newAddress) external override onlyWallet {
        require(newAddress != address(0), "Receiver cannot be 0.");
        uint256 currentId = nextTermsId[newAddress]++;
        vestingTerms[newAddress][currentId] = vestingTerms[oldAddress][oldTermsId];
        delete vestingTerms[oldAddress][oldTermsId];

        emit VestingTransferred(oldAddress, oldTermsId, newAddress, currentId);
    }

    function stopVesting(address receiver, uint256 termsId) external override onlyWallet {
        require(receiver != address(0), "Receiver cannot be 0.");

        VestingTerms storage terms = vestingTerms[receiver][termsId];
        require(isScheduleValid(terms), "No vesting data for receiver.");

        uint256 claimableTokens = _claimable(terms);
        uint256 revokedTokens = terms.amount - terms.claimed - claimableTokens;
        assert(terms.amount == (terms.claimed + claimableTokens + revokedTokens));

        // Update schedule to allow claiming the reminder.
        terms.period = 0;
        terms.amount = terms.claimed + claimableTokens;

        // Transfer the unclaimable (revoked) part.
        if (revokedTokens > 0) {
            token.safeTransfer(wallet, revokedTokens);
        }

        emit VestingRemoved(receiver, termsId);
    }

    function claimable(address receiver, uint256 termsId) external view override returns (uint256) {
        VestingTerms memory terms = vestingTerms[receiver][termsId];
        require(isScheduleValid(terms), "No vesting data for receiver.");
        return _claimable(terms);
    }

    function _claimable(VestingTerms memory terms) private view returns (uint256 claimableTokens) {
        if (terms.firstClaimableAt <= block.timestamp) {
            uint256 timePassed = block.timestamp - terms.startTime;
            uint256 maxTokens = (block.timestamp >= terms.startTime + terms.period)
                ? terms.amount
                : (terms.amount * timePassed) / terms.period;

            if (terms.claimed < maxTokens) {
                claimableTokens = maxTokens - terms.claimed;
            }
        }
    }

    function isScheduleValid(VestingTerms memory terms) private pure returns (bool) {
        return terms.startTime != 0;
    }
}
