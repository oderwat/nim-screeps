# nim build --verbosity:1 --hints:off
# run done
#
# sim1 example for Screep
#
# (c) 2016 by Hans Raaf of METATEXX GmbH

import screeps

screepsLoop: # this conaints the main loop which is exported to the game

  # Spawn creatures endlessly as soon as enought energy is available
  discard game.spawns.?Spawn1.createCreep(@[WORK, CARRY, MOVE], nil, nil)

  # Let them harvest energy at the first source and transfert it to the spawn
  for creep in game.creeps:
    # > Do what you are told, the whip!
    if creep.carry.energy < creep.carryCapacity:
      var sources = creep.room.find(Source);
      # harvest energy if near the source
      if creep.harvest(sources[0]) == ERR_NOT_IN_RANGE:
        # move to the source
        creep.moveTo(sources[0]);
    elif game.spawns.?Spawn1.energy < game.spawns.?Spawn1.energyCapacity:
      # our spawn needs more energy. transfer it there
      if creep.transfer(game.spawns.?Spawn1, RESOURCE_TYPE_ENERGY) == ERR_NOT_IN_RANGE:
        # uh not near the spawn. move there!
        creep.moveTo(game.spawns.?Spawn1);
