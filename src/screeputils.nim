# screeputils (test imports)
import screeps

proc transferAllCurrentCarry*(src, dst: Creep): int =
  if src.carry == nil:
    return ERR_NOT_ENOUGH_ENERGY

  result = OK;

  for stuff in keys(src.carry):
    result = src.transfer(dst, stuff)
    if result != OK and result != ERR_NOT_ENOUGH_RESOURCES:
      return result
