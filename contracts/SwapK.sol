// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Swap.sol";

/**
 * @title SwapK
 * @dev Generalized multi-way swap up to length k using depth-first search with adjacency pruning.
 * WARNING: On-chain cycle detection beyond small k is extremely expensive in gas!
 */
contract SwapK is Swap {
    event MultiWaySwapExecuted(
        uint8 cycleLength,
        uint256[] orderIds,
        address[] students,
        uint256[] tokenIds
    );
    event NoMultiSwapFound(uint8 cycleLength);

    uint8 private targetLen;
    uint256[] private activeOrders;
    mapping(uint256 => uint256) private idToIndex;
    bool[] private used;
    uint256[] private path;

    constructor(address _courseToken) Swap(_courseToken) {}

    /**
     * @dev Attempts to find and execute *any* cycles of exactly length `k`.
     */
    function executeMultiWaySwaps(uint8 k) external onlyOwner {
        require(k >= 2, "Cycle length must be ≥2");

        targetLen = k;
        uint256 n = orderIds.length;

        // Build a list of active orders
        delete activeOrders;
        for (uint256 i = 0; i < n; i++) {
            uint256 oid = orderIds[i];
            if (orders[oid].active) {
                idToIndex[oid] = activeOrders.length;
                activeOrders.push(oid);
            }
        }

        used = new bool[](activeOrders.length);
        path = new uint256[](k);

        // Try DFS from each active order as start
        for (uint256 i = 0; i < activeOrders.length; i++) {
            uint256 startId = activeOrders[i];
            dfs(startId, startId, 0);
            // if you want only one cycle, you could break here
        }

        // If no cycles found, notify
        if (path[0] == 0) {
            emit NoMultiSwapFound(k);
        }
    }

    /// @dev Depth‐first search building a path of length up to targetLen
    function dfs(
        uint256 startId,
        uint256 currentId,
        uint256 depth
    ) internal {
        uint256 idx = idToIndex[currentId];
        used[idx] = true;
        path[depth] = currentId;

        if (depth + 1 == targetLen) {
            // Closing condition: current requests what start offers?
            Order storage A = orders[startId];
            Order storage C = orders[currentId];
            (string memory offeredA, , , ) = courseToken.courseDetails(A.offeredTokenId);
            if (
                keccak256(bytes(C.requestedCourseID)) ==
                keccak256(bytes(offeredA))
            ) {
                // Validate full cycle
                if (_validatePath(targetLen)) {
                    _executePath(targetLen);
                }
            }
        } else {
            // Prune: get the course currentId wants
            bytes32 want = keccak256(
                bytes(orders[currentId].requestedCourseID)
            );
            // For each neighbor offering want
            for (uint256 j = 0; j < activeOrders.length; j++) {
                if (used[j]) continue;
                uint256 nextId = activeOrders[j];
                (, , , string memory offNext) =
                    courseToken.courseDetails(orders[nextId].offeredTokenId);
                if (keccak256(bytes(offNext)) != want) {
                    continue;
                }
                dfs(startId, nextId, depth + 1);
            }
        }

        // backtrack
        used[idx] = false;
    }

    /// @dev Validates ownership, timing & duplicate‐course for the built path
    function _validatePath(uint256 len) internal view returns (bool) {
        for (uint256 i = 0; i < len; i++) {
            uint256 id1 = path[i];
            uint256 id2 = path[(i + 1) % len];
            Order storage O1 = orders[id1];
            Order storage O2 = orders[id2];

            // ownership
            if (courseToken.ownerOf(O1.offeredTokenId) != O1.student)
                return false;
            // timing & duplicates
            if (_hasTimingConflict(
                    O1.student,
                    O1.offeredTokenId,
                    O2.offeredTokenId
                ) ||
                _hasCourseConflict(
                    O1.student,
                    O1.offeredTokenId,
                    O2.offeredTokenId
                )
            ) return false;
        }
        return true;
    }

    /// @dev Executes the swaps of the validated path, emits event
    function _executePath(uint256 len) internal {
        address[] memory studs = new address[](len);
        uint256[] memory toks = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            uint256 currId = path[i];
            uint256 nextId = path[(i + 1) % len];
            Order storage O1 = orders[currId];
            Order storage O2 = orders[nextId];

            courseToken.safeTransferFrom(
                O1.student,
                O2.student,
                O1.offeredTokenId
            );

            studs[i] = O1.student;
            toks[i] = O1.offeredTokenId;
            // mark inactive
            orders[currId].active = false;
        }

        emit MultiWaySwapExecuted(
            targetLen,
            path,
            studs,
            toks
        );
    }
}
