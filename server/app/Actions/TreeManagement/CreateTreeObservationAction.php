<?php

namespace App\Actions\TreeManagement;

use App\Models\Tree;
use App\Models\Observation;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

/**
 * Action to create a tree observation (e.g. flowering status observation).
 *
 * Usage:
 *   (new \App\Actions\TreeManagement\CreateTreeObservationAction())->execute($tree, $harvestUuid, $floweringStatus);
 */
class CreateTreeObservationAction
{
    /**
     * Create an observation record for the given tree.
     *
     * @param Tree $tree
     * @param string $harvestUuid
     * @param string $floweringStatus One of: A,B,C,D,X
     * @return Observation
     * @throws InvalidArgumentException
     */
    public function execute(Tree $tree, string $harvestUuid, string $floweringStatus): Observation
    {
        $allowed = ['A', 'B', 'C', 'D', 'X'];
        if (!in_array($floweringStatus, $allowed, true)) {
            throw new InvalidArgumentException('Invalid flowering status: ' . $floweringStatus);
        }

        return DB::transaction(function () use ($tree, $harvestUuid, $floweringStatus) {
            // Ensure Observation model exists; set fields commonly expected.
            $observation = new Observation();
            if (property_exists($observation, 'uuid')) {
                $observation->uuid = Str::uuid()->toString();
            }

            // Link to tree (by numeric id or uuid depending on your model)
            if (isset($tree->id)) {
                // use numeric id if model uses it
                if (property_exists($observation, 'tree_id')) {
                    $observation->tree_id = $tree->id;
                }
            }

            // Some schemas use tree_uuid instead of tree_id
            if (property_exists($observation, 'tree_uuid')) {
                $observation->tree_uuid = $tree->uuid ?? null;
            }

            // Set harvest reference and observation payload
            if (property_exists($observation, 'harvest_uuid')) {
                $observation->harvest_uuid = $harvestUuid;
            } else {
                // fallback generic field name
                if (property_exists($observation, 'harvest_id')) {
                    $observation->harvest_id = $harvestUuid;
                }
            }

            if (property_exists($observation, 'flowering_status')) {
                $observation->flowering_status = $floweringStatus;
            }

            if (property_exists($observation, 'observed_at')) {
                $observation->observed_at = now();
            }

            $observation->save();

            return $observation;
        });
    }
}
