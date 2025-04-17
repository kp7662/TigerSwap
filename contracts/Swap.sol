// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Interface for CourseToken.
 */
interface ICourseToken {
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function courseDetails(uint256 tokenId)
        external
        view
        returns (string memory, string memory, string memory, string memory);
    function tokensOfOwner(address owner) external view returns (uint256[] memory);
}

contract Swap is Ownable {
    struct Order {
        uint256 orderId;
        address student;
        uint256 offeredTokenId;
        string requestedCourseID;
        bool active;
    }

    ICourseToken public courseToken;
    uint256 public orderCounter;
    mapping(uint256 => Order) public orders;
    uint256[] public orderIds;

    event OrderSubmitted(uint256 orderId, address indexed student, uint256 offeredTokenId, string requestedCourseID);
    event OrderCancelled(uint256 orderId, address indexed student);
    event SwapExecuted(uint256 orderId1, uint256 orderId2, uint256 tokenId1, uint256 tokenId2);

    event SwapExecutedVerbose(
        uint256 orderId1,
        address student1,
        string courseID1,
        string preceptID1,
        uint256 orderId2,
        address student2,
        string courseID2,
        string preceptID2
    );

    constructor(address _courseTokenAddress) Ownable() {
        courseToken = ICourseToken(_courseTokenAddress);
    }

    function submitOrder(uint256 offeredTokenId, string memory requestedCourseID) public {
        require(courseToken.ownerOf(offeredTokenId) == msg.sender, "You do not own the offered token");
        orderCounter++;
        orders[orderCounter] = Order(orderCounter, msg.sender, offeredTokenId, requestedCourseID, true);
        orderIds.push(orderCounter);
        emit OrderSubmitted(orderCounter, msg.sender, offeredTokenId, requestedCourseID);
    }

    function cancelOrder(uint256 orderId) public {
        Order storage order = orders[orderId];
        require(order.active, "Order is not active");
        require(order.student == msg.sender, "Not your order");
        order.active = false;
        emit OrderCancelled(orderId, msg.sender);
    }

    function cancelAllOrders() public onlyOwner {
        for (uint256 i = 0; i < orderIds.length; i++) {
            uint256 oid = orderIds[i];
            if (orders[oid].active) {
                orders[oid].active = false;
                emit OrderCancelled(oid, orders[oid].student);
            }
        }
    }

    struct OrderWithMetadata {
        uint256 orderId;
        address student;
        uint256 offeredTokenId;
        string requestedCourseID;
        string courseID;
        string preceptID;
        string timing;
        string coursePageURL;
    }

    function getActiveOrdersWithMetadata() public view onlyOwner returns (OrderWithMetadata[] memory) {
        uint256 cnt;
        for (uint256 i = 0; i < orderIds.length; i++) {
            if (orders[orderIds[i]].active) cnt++;
        }

        OrderWithMetadata[] memory results = new OrderWithMetadata[](cnt);
        uint256 idx;

        for (uint256 i = 0; i < orderIds.length; i++) {
            uint256 oid = orderIds[i];
            if (!orders[oid].active) continue;
            Order storage o = orders[oid];
            (string memory cID, string memory pID, string memory tm, string memory url) =
                courseToken.courseDetails(o.offeredTokenId);

            results[idx++] = OrderWithMetadata(
                o.orderId, o.student, o.offeredTokenId, o.requestedCourseID,
                cID, pID, tm, url
            );
        }
        return results;
    }

    function executeSwaps() public onlyOwner {
        uint256 n = orderIds.length;
        for (uint256 i = 0; i < n; i++) {
            uint256 id1 = orderIds[i];
            if (!orders[id1].active) continue;

            Order storage o1 = orders[id1];
            (string memory c1, , , ) = courseToken.courseDetails(o1.offeredTokenId);

            for (uint256 j = i + 1; j < n; j++) {
                uint256 id2 = orderIds[j];
                if (!orders[id2].active) continue;

                Order storage o2 = orders[id2];
                (string memory c2, , , ) = courseToken.courseDetails(o2.offeredTokenId);

                if (
                    keccak256(bytes(o1.requestedCourseID)) == keccak256(bytes(c2)) &&
                    keccak256(bytes(o2.requestedCourseID)) == keccak256(bytes(c1))
                ) {
                    address s1 = o1.student;
                    address s2 = o2.student;
                    uint256 t1 = o1.offeredTokenId;
                    uint256 t2 = o2.offeredTokenId;

                    require(courseToken.ownerOf(t1) == s1, "Owner mismatch t1");
                    require(courseToken.ownerOf(t2) == s2, "Owner mismatch t2");

                    // timing & dup checks
                    if (_hasTimingConflict(s1, t1, t2) ||
                        _hasTimingConflict(s2, t2, t1) ||
                        _hasCourseConflict(s1, t1, t2) ||
                        _hasCourseConflict(s2, t2, t1)
                    ) continue;

                    // atomic swap
                    courseToken.safeTransferFrom(s1, s2, t1);
                    courseToken.safeTransferFrom(s2, s1, t2);

                    o1.active = false;
                    o2.active = false;

                    emit SwapExecuted(id1, id2, t1, t2);

                    {
                        (string memory cc1, string memory pp1, , ) =
                            courseToken.courseDetails(t1);
                        (string memory cc2, string memory pp2, , ) =
                            courseToken.courseDetails(t2);

                        emit SwapExecutedVerbose(
                            id1, s1, cc1, pp1,
                            id2, s2, cc2, pp2
                        );
                    }
                    break;
                }
            }
        }
    }

    // instead of tokenOfOwnerByIndex, use the helper:
    function _getTokens(address who) internal view returns (uint256[] memory) {
        return courseToken.tokensOfOwner(who);
    }

    function _hasTimingConflict(address student, uint256 drop, uint256 incoming) internal view returns (bool) {
        uint256[] memory regs = _getTokens(student);
        (, , string memory inT, ) = courseToken.courseDetails(incoming);
        for (uint i = 0; i < regs.length; i++) {
            if (regs[i] == drop) continue;
            (, , string memory rT, ) = courseToken.courseDetails(regs[i]);
            if (keccak256(bytes(rT)) == keccak256(bytes(inT))) {
                return true;
            }
        }
        return false;
    }

    function _hasCourseConflict(address student, uint256 drop, uint256 incoming) internal view returns (bool) {
        uint256[] memory regs = _getTokens(student);
        (string memory inCID, , , ) = courseToken.courseDetails(incoming);
        for (uint i = 0; i < regs.length; i++) {
            if (regs[i] == drop) continue;
            (string memory rCID, , , ) = courseToken.courseDetails(regs[i]);
            if (keccak256(bytes(rCID)) == keccak256(bytes(inCID))) {
                return true;
            }
        }
        return false;
    }
}
