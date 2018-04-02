pragma solidity ^0.4.18;

import './fund/ICrowdsaleReservationFund.sol';
import './ISimpleCrowdsale.sol';
import './ownership/Ownable.sol';
import './math/SafeMath.sol';


contract ReservationFund is ICrowdsaleReservationFund, Ownable, SafeMath {
    bool public crowdsaleFinished = false;

    mapping(address => uint256) contributions;
    mapping(address => uint256) tokensToIssue;
    mapping(address => uint256) bonusTokensToIssue;

    ISimpleCrowdsale public crowdsale;

    event ReservationFundContribution(address contributor, uint256 etherAmount, uint256 tokensToIssue, uint256 bonusTokensToIssue);
    event RefundPayment(address contributor, uint256 etherAmount);
    event FinishCrowdsale();

    function ReservationFund(address _owner) public Ownable(_owner) {
    }

    modifier onlyCrowdsale() {
        require(msg.sender == address(crowdsale));
        _;
    }

    function setCrowdsaleAddress(address crowdsaleAddress) public onlyOwner {
        crowdsale = ISimpleCrowdsale(crowdsaleAddress);
    }

    function contributionsOf(address contributor) external returns(uint256) {
        return contributions[contributor];
    }

    /**
     * @dev Process crowdsale contribution without whitelist
     */
    function processContribution(
        address contributor,
        uint256 _tokensToIssue,
        uint256 _bonusTokensToIssue
    ) external payable onlyCrowdsale {
        contributions[contributor] = safeAdd(contributions[contributor], msg.value);
        tokensToIssue[contributor] = safeAdd(tokensToIssue[contributor], _tokensToIssue);
        bonusTokensToIssue[contributor] = safeAdd(bonusTokensToIssue[contributor], _bonusTokensToIssue);

        ReservationFundContribution(contributor,msg.value, _tokensToIssue, _bonusTokensToIssue);
    }

    function completeContribution(address contributor) public {
        require(!crowdsaleFinished);
        require(crowdsale.isContributorInLists(contributor));
        require(contributions[contributor] > 0);

        uint256 etherAmount = contributions[contributor];
        uint256 tokenAmount = tokensToIssue[contributor];
        uint256 tokenBonusAmount = bonusTokensToIssue[contributor];

        contributions[contributor] = 0;
        tokensToIssue[contributor] = 0;
        bonusTokensToIssue[contributor] = 0;

        crowdsale.processReservationFundContribution.value(etherAmount)(contributor, tokenAmount, tokenBonusAmount);
    }

    function onCrowdsaleEnd() external {
        crowdsaleFinished = true;
        FinishCrowdsale();
    }

    function refundPayment(address contributor) public {
        require(crowdsaleFinished);
        require(contributions[contributor] > 0 || tokensToIssue[contributor] > 0);
        uint256 amountToRefund = contributions[contributor];

        contributions[contributor] = 0;
        tokensToIssue[contributor] = 0;
        bonusTokensToIssue[contributor] = 0;

        contributor.transfer(amountToRefund);
        RefundPayment(contributor, amountToRefund);
    }
}
