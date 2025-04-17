// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Swap.sol";

contract Swap3Adj is Swap {
    event ThreeWaySwapExecuted(
        uint256 orderId1, address student1, uint256 tokenId1,
        uint256 orderId2, address student2, uint256 tokenId2,
        uint256 orderId3, address student3, uint256 tokenId3
    );
    event NoThreeWaySwapFound();
    event TwoWaySwapCompleted();

    constructor(address _courseTokenAddress) Swap(_courseTokenAddress) {}

    /**
    * @dev Find and execute all 3‑way cycles by pruning on offered→requested adjacency.
    */
    function executeThreeWaySwaps() public onlyOwner {
        bool found = false;
        uint256 n = orderIds.length;

        // Outer loop: pick A
        for (uint256 i = 0; i < n; i++) {
            uint256 idA = orderIds[i];
            Order storage A = orders[idA];
            if (!A.active) continue;

            // Cache A’s offered course for final check
            (string memory offeredA, , , ) = courseToken.courseDetails(A.offeredTokenId);
            // Hash of the course A requests
            bytes32 wantA = keccak256(bytes(A.requestedCourseID));

            // Middle loop: pick B among orders offering exactly wantA
            for (uint256 j = 0; j < n; j++) {
                uint256 idB = orderIds[j];
                if (idB == idA) continue;
                Order storage B = orders[idB];
                if (!B.active) continue;

                // Does B offer what A wants?
                (string memory offeredB, , , ) = courseToken.courseDetails(B.offeredTokenId);
                if (keccak256(bytes(offeredB)) != wantA) continue;

                // Hash of the course B requests
                bytes32 wantB = keccak256(bytes(B.requestedCourseID));

                // Inner loop: pick C among orders offering exactly wantB
                for (uint256 k = 0; k < n; k++) {
                    uint256 idC = orderIds[k];
                    if (idC == idA || idC == idB) continue;
                    Order storage C = orders[idC];
                    if (!C.active) continue;

                    // Does C offer what B wants?
                    (string memory offeredC, , , ) = courseToken.courseDetails(C.offeredTokenId);
                    if (keccak256(bytes(offeredC)) != wantB) continue;

                    // Finally, does C request A’s offered course?
                    if (keccak256(bytes(C.requestedCourseID)) != keccak256(bytes(offeredA))) {
                        continue;
                    }

                    // All three point in a cycle; validate conflicts & ownership
                    if (_validateThree(A, B, C)) {
                        // Execute the 3‑way circular swap
                        courseToken.safeTransferFrom(A.student, C.student, A.offeredTokenId);
                        courseToken.safeTransferFrom(B.student, A.student, B.offeredTokenId);
                        courseToken.safeTransferFrom(C.student, B.student, C.offeredTokenId);

                        // Mark inactive
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

        if (!found) {
            emit NoThreeWaySwapFound();
        }
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
