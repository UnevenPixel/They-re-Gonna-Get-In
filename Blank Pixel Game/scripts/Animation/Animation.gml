function AnimationLibrary(_idle, _walk, _attack, _special = []) constructor{
    idle = _idle;
    walk = _walk;
    attack = _attack;
    for(var i = 0; i < array_length(_special); i ++){
        variable_struct_set(self,_special[i].name,_special[i].sprite);
    }
}