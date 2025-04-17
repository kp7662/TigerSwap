// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Swap.sol";

contract Swap3Brute is Swap {
    event ThreeWaySwapExecuted(
        uint256 orderId1, address student1, uint256 tokenId1,
        uint256 orderId2, address student2, uint256 tokenId2,
        uint256 orderId3, address student3, uint256 tokenId3
    );
    event NoThreeWaySwapFound();
    event TwoWaySwapCompleted();

    constructor(address _courseTokenAddress) Swap(_courseTokenAddress) {}

    function executeThreeWaySwaps() public onlyOwner {
        bool found;
        uint256 n = orderIds.length;

        for (uint i = 0; i < n; i++) {
            if (!orders[orderIds[i]].active) continue;
            for (uint j = i + 1; j < n; j++) {
                if (!orders[orderIds[j]].active) continue;
                for (uint k = j + 1; k < n; k++) {
                    if (!orders[orderIds[k]].active) continue;

                    Order storage A = orders[orderIds[i]];
                    Order storage B = orders[orderIds[j]];
                    Order storage C = orders[orderIds[k]];

                    (string memory cA, , , ) = courseToken.courseDetails(A.offeredTokenId);
                    (string memory cB, , , ) = courseToken.courseDetails(B.offeredTokenId);
                    (string memory cC, , , ) = courseToken.courseDetails(C.offeredTokenId);

                    if (
                        keccak256(bytes(A.requestedCourseID)) == keccak256(bytes(cB)) &&
                        keccak256(bytes(B.requestedCourseID)) == keccak256(bytes(cC)) &&
                        keccak256(bytes(C.requestedCourseID)) == keccak256(bytes(cA))
                    ) {
                        // validate ownership & conflicts
                        if (_validateThree(A, B, C)) {
                            // circular swap
                            courseToken.safeTransferFrom(A.student, C.student, A.offeredTokenId);
                            courseToken.safeTransferFrom(B.student, A.student, B.offeredTokenId);
                            courseToken.safeTransferFrom(C.student, B.student, C.offeredTokenId);

                            A.active = false;
                            B.active = false;
                            C.active = false;

                            emit ThreeWaySwapExecuted(
                                A.orderId, A.student, A.offeredTokenId,
                                B.orderId, B.student, B.offeredTokenId,
                                C.orderId, C.student, C.offeredTokenId
                            );
                            found = true;
                        }
                    }
                }
            }
        }

        if (!found) emit NoThreeWaySwapFound();
    }

    function executeTwoWaySwaps() public onlyOwner {
        super.executeSwaps();
        emit TwoWaySwapCompleted();
    }

    function _validateThree(
        Order memory A,
        Order memory B,
        Order memory C
    ) internal view returns (bool) {
        // ownership
        if (
            courseToken.ownerOf(A.offeredTokenId) != A.student ||
            courseToken.ownerOf(B.offeredTokenId) != B.student ||
            courseToken.ownerOf(C.offeredTokenId) != C.student
        ) return false;

        // timing & duplicates
        if (
            _hasTimingConflict(A.student, A.offeredTokenId, B.offeredTokenId) ||
            _hasTimingConflict(B.student, B.offeredTokenId, C.offeredTokenId) ||
            _hasTimingConflict(C.student, C.offeredTokenId, A.offeredTokenId) ||
            _hasCourseConflict(A.student, A.offeredTokenId, B.offeredTokenId) ||
            _hasCourseConflict(B.student, B.offeredTokenId, C.offeredTokenId) ||
            _hasCourseConflict(C.student, C.offeredTokenId, A.offeredTokenId)
        ) return false;

        return true;
    }
}
