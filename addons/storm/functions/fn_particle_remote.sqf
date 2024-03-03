/*
 * Author: [Zorn]
 * Function to apply the Particle Effects - Handles creation, deletion and adjustment of intensity of particlespawners on each client locally.
 * Intensity will be regulated simply by dropInterval (The bigger the number, the less particles)
 * If the same Effect has already been called, it will instead adjust the already existing PE spawner.
 * If _intensityTarget == 0, the function will ether exit in case the spawner doesnt exist already or transition the spawner to 0 intensity and afterwards, the spawner will be deleted.  
 *
 * Arguments:
 * 0: _EffectName           <STRING> CfgCloudlet Classname of the desired Particle Effect. 
 * 1: _intensityTarget      <Number> 0..1 Intensity of Effect with 1 having the strongest Effect. 
 * 2: _duration             <Number> in seconds. Defines the Duration of the Transition. 
 *
 * Return Value:
 * none - intended to be remoteExecCall -> returns JIP Handle
 *
 * Note: 
 *
 * Example:
 *
 * ["CVO_PE_Leafes", 600, 0.75] remoteExecCall ["cvo_storm_fnc_particle_remote",0, _jip_handle_string];
 * ["CVO_PE_Leafes", 600]       remoteExecCall ["cvo_storm_fnc_particle_remote",0, _jip_handle_string];
 * ["CLEANUP"]                  remoteExecCall ["cvo_storm_fnc_particle_remote",0, _jip_handle_string];
 * ["CLEANUP"]                  call cvo_storm_fnc_particle_remote
 * 
 * Public: No
 */

#define COEF_SPEED 5
#define COEF_WIND  0.2
#define PFEH_ATTACH_DELAY 0
#define PFEH_INTENSITY_DELAY 4 // _duration /  PFEH_INTENSITY_DELAY == _delay
#define INTERVAL_MINIMUM 20



if (!hasInterface) exitWith {};

params [
    ["_effectName",        "",       [""]],
    ["_duration",         300,        [0]],
    ["_intensityTarget",    0,        [0]]
];

if ( _effectName isEqualTo "CLEANUP")  exitWith {
    if ( missionNamespace getVariable ["CVO_Debug", false] ) then {   CVO_Storm_Local_PE_Spawner_array deleteAt 0;};
    {  
        [ _x getVariable ["CVO_PE_Spawner_Name", ""] ] call cvo_storm_fnc_particle_remote;
    } forEach CVO_Storm_Local_PE_Spawner_array;
};

if ( _effectName isEqualTo "")  exitWith {};
if (_intensityTarget < 0 )      exitWith {};
if (_duration    isEqualTo  0)  exitWith {};

if (isNil "CVO_Storm_Local_PE_Spawner_array") then {
    diag_log "Array Created:";
    diag_log str CVO_Storm_Local_PE_Spawner_array;
    CVO_Storm_Local_PE_Spawner_array = [];

    // Adds Debug_Helper Object (arrow)
    if (missionNamespace getVariable ["CVO_Debug", false]) then {
            _helper = createVehicleLocal [ "Sign_Arrow_Large_F", [0,0,0] ];
            _helper setVariable ["CVO_PE_Spawner_Name", "Debug_helper", false];
            CVO_Storm_Local_PE_Spawner_array pushback _helper;
            diag_log "Helper Created:";
            diag_log str CVO_Storm_Local_PE_Spawner_array;

    };

    // Start pfEH to re-attach all Particle Spawners according to player speed & wind.
    // watch CVO_particle_isActive, if inactive, delete particle spawners and pfEH

    private _codeToRun = {
        //_SpeedVector vectorDiff _windVector
        private _player = vehicle ace_player;  
        private _relPosArray = (( velocityModelSpace _player ) vectorMultiply COEF_SPEED) vectorDiff (( _player vectorWorldToModel wind ) vectorMultiply COEF_WIND);
        _relPosArray set [2, (_relPosArray#2) + 1 ];
        { _x attachTo [_player, _relPosArray]; } forEach CVO_Storm_Local_PE_Spawner_array;
    };
    private _exitCode  = { 
    diag_log "reAttach pfEH Exit";
        { deleteVehicle _x } forEach CVO_Storm_Local_PE_Spawner_array; 
        CVO_Storm_Local_PE_Spawner_array = nil;  
    };

    private _condition = { ( missionNameSpace getVariable ["CVO_particle_isActive", false] ) || ( count CVO_Storm_Local_PE_Spawner_array > 0 ) };
    private _delay = PFEH_ATTACH_DELAY;

    [{
        params ["_args", "_handle"];
        _args params ["_codeToRun", "_exitCode", "_condition"];

        if ([] call _condition) then {
            [] call _codeToRun;
        } else {
            _handle call CBA_fnc_removePerFrameHandler;
            [] call _exitCode;
        };
    }, _delay, [_codeToRun, _exitCode, _condition]] call CBA_fnc_addPerFrameHandler;
};

// Defines custom Variablename as String 
// missionNameSpace has only lowercase letters

private _spawnerName = toLower (["CVO_Storm_Particle_",_effectName,"_particlesource"] joinString "");

////////////////////////////////////////////////////////////////////////////////////////////////////
// Check if a spawner of that type already exists, 
// if not, create, setParticleClass, setVariables and add it to the array.
// if already exists, take previous intensity and set as start inensity. 
////////////////////////////////////////////////////////////////////////////////////////////////////

private _intensityStart = 0;
private "_spawner";
private _index = CVO_Storm_Local_PE_Spawner_array findIf { ( _x getVariable [ "CVO_PE_Spawner_Name" , "" ] ) isEqualTo _spawnerName };

private _DropIntervalStart = INTERVAL_MINIMUM;
private _DropIntervalMax = ([_effectName] call BIS_fnc_getCloudletParams) select 2; // #0 setParticleParams, #1 setParticleRandom, #2 setDropInterval
private _DropIntervalTarget = linearConversion [0, 1, _intensityTarget, _DropIntervalStart, _DropIntervalMax, true];



diag_log format ["_index: %1", _index];


if (_index == -1) then {

    _spawner = "#particlesource" createVehicleLocal [0,0,0];
    _spawner setParticleClass _effectName;

    _spawner setVariable ["CVO_PE_Spawner_Name", _spawnerName]; 
    _spawner setVariable ["CVO_PE_Spawner_Intensity", _intensity];
    CVO_Storm_Local_PE_Spawner_array pushback _spawner;

    diag_log format ["PES created: %1 - Intensity: %2 - Array: %3", _spawnerName,_intensity,CVO_Storm_Local_PE_Spawner_array];
} else {
    _spawner = CVO_Storm_Local_PE_Spawner_array select _index;
    _intensityStart = _spawner getVariable ["CVO_PE_Spawner_Intensity", 0];
    diag_log format ["PES Adjsuted: %1 - Intensity: %2 - Array: %3", _spawnerName,_intensity,CVO_Storm_Local_PE_Spawner_array];
};

diag_log format ["_intensityStart: %1 - _intensity: %2 - _DropIntervalStart: %3 - _DropIntervalTarget: %4 - _DropIntervalMax: %5", _intensityStart, _intensity, _DropIntervalStart, _DropIntervalTarget, _DropIntervalMax];


////////////////////////////////////////////////////////////////////////////////////////////////////
///////////// Particle Intensity will simply be adjusted over time via setDropInterval /////////////
///////////// Maybe in Future, Intensity could be applied via colorAlpha, Size, ...    /////////////
///////////// Problem: bad solution solution for non-dust-like particles like leafes   /////////////
///////////// Therefore, for now, particle quantitiy has been chosen as the regulator  /////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

private _startTime = time;
private _endTime = _startTime + _duration;
diag_log format ["Transition _startTime: %1 _endTime: %2", _startTime, _endTime];


//// params inside the pfEH
private _parameters = [ _spawner, _startTime, _endTime, _DropIntervalStart, _DropIntervalTarget, _intensityTarget  ];

private _codeToRun = {
    params [ "_spawner", "_startTime", "_endTime", "_DropIntervalStart", "_DropIntervalTarget", "_intensityTarget"  ];
    _drop = linearConversion [ _startTime, _endTime, time, _dropIntervalStart, _dropIntervalTarget ];
    diag_log format ["PE: %1 setDropInterval: %2", _spawner getVariable ["CVO_PE_Spawner_Name",""], _drop];
    _spawner setDropInterval _drop;
}; 

private _exitCode = {   
    params [ "_spawner", "_startTime", "_endTime", "_DropIntervalStart", "_DropIntervalTarget", "_intensityTarget"  ];
    diag_log "Transition pfEH Exit";
    _spawner setDropInterval  _dropIntervalTarget; 
    if ( _intensityTarget isEqualTo 0) then {
        diag_log "Transition pfEH Exit - Intensity == 0 -> Spawner Deleted";
        CVO_Storm_Local_PE_Spawner_array = CVO_Storm_Local_PE_Spawner_array - [_spawner];   
        deleteVehicle _spawner;
    };
};

private _condition = {  _this#2 >= time };

private _delay = _duration / PFEH_INTENSITY_DELAY;

[{
    params ["_args", "_handle"];
    _args params ["_codeToRun", "_parameters", "_exitCode", "_condition"];

    if (_parameters call _condition) then {
        _parameters call _codeToRun;
    } else {
        _handle call CBA_fnc_removePerFrameHandler;
        _parameters call _exitCode;
    };
}, _delay, [_codeToRun, _parameters, _exitCode, _condition]] call CBA_fnc_addPerFrameHandler;