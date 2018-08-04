<?php
// COMP3311 18s1 Assignment 2
// Functions for assignment Tasks A-E
// Written by <<MEHRI AMIN>> (<<Z5113067>>), May 2018

// assumes that defs.php has already been included


// Task A: get members of an academic object group

// E.g. list($type,$codes) = membersOf($db, 111899)
// Inputs:
//  $db = open database handle
//  $groupID = acad_object_group.id value
// Outputs:
//  array(GroupType,array(Codes...))
//  GroupType = "subject"|"stream"|"program"
//  Codes = acad object codes in alphabetical order
//  e.g. array("subject",array("COMP2041","COMP2911"))

function membersOf($db,$groupID)
{
  
  $q = "SELECT * FROM acad_object_groups a WHERE a.id = %d"; // query
  $grp = dbOneTuple($db, mkSQL($q, $groupID)); // list of group
  $definition = $groupID; // definition for pattern case
  $array = array(); // create an array

  // Definitions
  $gdef = $grp["gdefby"]; 
  $gtype = $grp["gtype"];

  // PATTERN CASE
  if ($gdef == "pattern") {

    $data = dbQuery($db, mkSQL($q,$groupID,$groupID));

    switch($gtype){
      case "subject":
        $q = "SELECT subject.code FROM acad_object_groups a, subjects subject
              WHERE subject.code SIMILAR TO %s AND a.id = %d";
        break;

      case "stream":
        $q = "SELECT stream.code FROM acad_object_groups a, streams stream
              WHERE stream.code similar to %s AND a.id = %d";
        break;

      case "program":
        $q = "SELECT program.code FROM acad_object_groups a, programs program
              WHERE program.code similar to %s AND a.id = %d";
      break;
    }
    
    while ($t = dbNext($data)) {
      $definition = $t['definition'];
     
      if(stripos($definition, "GENG") !== false ||
         stripos($definition, "GEN#") !== false ||
         stripos($definition, "FREE") !== false ||
         stripos($definition, "####") !== false ||
         stripos($definition, "all")  !== false ||
         stripos($definition, "ALL")  !== false 
         )
      {
        
        return array($gtype, array($definition));
      }
       
       // else
      $definition = preg_replace('/,/', '|', $definition); // test04
      $definition = preg_replace('/{|}/', '', $definition);  //test05
      $definition = preg_replace('/;/', '|', $definition);  // test05
      $definition = preg_replace('/#{1,}/', '%', $definition); // test13 matches one or more hashes

    }
  }
  
  // ENUMERATED CASE
  elseif($gdef == "enumerated"){

    switch($gtype){
   
      case "subject":
        $q = "SELECT subject.code FROM acad_object_groups a
              JOIN subject_group_members sgm ON (a.id=sgm.ao_group)
              JOIN subjects subject ON (subject.id=sgm.subject)
              WHERE a.id = %d
              OR a.parent = %d";
      break;

      case "stream":
        $q = "SELECT stream.code FROM acad_object_groups a
              JOIN stream_group_members str ON (a.id=str.ao_group)
              JOIN streams stream ON (stream.id=str.stream)
              WHERE a.id = %d
              OR a.parent = %d";
      break;

      case "program":
        $q = "SELECT program.code FROM acad_object_groups a
              JOIN program_group_members pgm ON (a.id=pgm.ao_group)
              JOIN programs program ON (program.id = pgm.program)
              WHERE a.id = %d
              OR a.parent = %d";
      break;

    }
  }
  
  $data = dbQuery($db, mkSQL($q, $definition, $groupID));
      
  while ($t = dbNext($data)) {
    array_push($array, $t["code"]);
  }
  sort($array);
  return array($gtype, $array);
}


// Task B: check if given object is in a group

// E.g. if (inGroup($db, "COMP3311", 111938)) ...
// Inputs:
//  $db = open database handle
//  $code = code for acad object (program,stream,subject)
//  $groupID = acad_object_group.id value
// Outputs:
//  true/false

/* "FREE", "####", "all", or "ALL" include any subject 
    whose first three characters are not "GEN"

  "GENG", "GEN#" include any subject whose first three characters are "GEN"

  "GENG####/F=SCI" includes any subject whose first three characters are 
  "GEN" and which is offered by the Science Faculty or some school 
  under the Science Faculty

  "GENE####" includes any subject whose first four letters are "GENE", etc.

  "!Pattern" excludes any subjects matching the pattern from the group
*/

function inGroup($db, $code, $groupID)
{
  $q = "select * from acad_object_groups a where a.id = %d";
  $grp = dbOneTuple($db, mkSQL($q, $groupID));
  $array = array(); 

  // enumerated case
  list($type,$codes) = membersOf($db, $groupID);   
  
  if (in_array($code, $codes)) {
   /* foreach($codes as $pattern){
      echo $pattern."\n";
    }*/
    return true;
  }
  //echo $code . "\n";
  // search through codes

  // pattern case
  foreach($codes as $pattern) {
   // echo $pattern . "\n";
    if(substr($pattern,0,4) == "####" ||
       substr($pattern,0,4) == "FREE" ||
       substr($pattern,0,4) == "all" ||
       substr($pattern,0,4) == "ALL") {

      if(substr($code, 0, 3) != "GEN") {
      
        $prefix = substr($code,0,4); 
        $suffix = substr($pattern, 4, 20);
        $result = $prefix.$suffix;
        $result = preg_replace('/#{1,}/','%',$result);

        $length = strlen($code);

        switch($length) {
        
          case 8:
            $q = "SELECT subject.code FROM acad_object_groups a, subjects subject
                  WHERE subject.code SIMILAR TO %s AND a.id = %d";
          break;

          case 6:
            $q = "SELECT stream.code FROM acad_object_groups a, streams stream
                  WHERE stream.code similar to %s and a.id = %d";
          break;

          case 4:
            $q = "SELECT program.code FROM acad_object_groups a, programs program
                  WHERE program.code similar to %s and a.id = %d";
          break;
        } 
      }

      $data = dbQuery($db, mkSql($q, $result, $groupID));

      while($t = dbNext($data)) {
        array_push($array, $t["code"]);
      }
      
      if(in_array($code, $array)) 
        return true;
    
    // IF GENG OR GEN#
    }elseif(substr($pattern,0,4) == "GENG" ||
           substr($pattern,0,4) == "GEN#") {

      if(substr($code, 0, 3) == "GEN") 
        return true;
    }
  }
  
  return false;
}


// Task C: can a subject be used to satisfy a rule

// E.g. if (canSatisfy($db, "COMP3311", 2449, $enr)) ...
// Inputs:
//  $db = open database handle
//  $code = code for acad object (program,stream,subject)
//  $ruleID = rules.id value
//  $enr = array(ProgramID,array(StreamIDs...))
// Outputs:

function canSatisfy($db, $code, $ruleID, $enrolment)
{
  $q = "SELECT * FROM rules rule JOIN acad_object_groups a ON (rule.ao_group=a.id)
        WHERE rule.id = %d";
 
  $aog = dbOneTuple($db, mkSQL($q, $ruleID));
  
  $gdef = $aog["gdefby"];
  $groupID = $aog["id"];
  $type = $aog["type"];

  if ($gdef == "pattern") {

    if(preg_match('/^[A-Z]{5}[A-Z0-9]$/',$code)){
      $sql = "streams";
  
    }elseif(preg_match('/^[A-Z]{4}[0-9]{4}$/',$code)){
      $sql = "subjects";
    } // program codes not relevant


    if (substr($code,0,3) == "GEN") {
      if (inGroup($db, $code, $groupID)) {
        
        // get the faculty of the program
        $q = "select facultyOf(offeredBy) as faculty from programs where id = %d";
        $progFaculty = dbOneValue($db, mkSql($q,$enrolment[0]));

        // get the faculty of the code        
        $q = "select facultyOf(offeredBy) as faculty from $sql where code = %s";
        $codeFaculty = dbOneValue($db, mkSQL($q,$code));
      
        // if not in same faculty, it can satisfy
        if($codeFaculty != $progFaculty) return true; 
      }
    } 
  }  
  elseif ($gdef == "enumerated") {
  
      // if code is in group array return true
      list($type,$codes) = membersOf($db, $groupID);

      if (in_array($code, $codes)) {
        return true;
      }  
  }
  return false; // stub
}



// Task D: determine student progress through a degree

// E.g. $vtrans = progress($db, 3012345, "05s1");
// Inputs:
//  $db = open database handle
//  $stuID = People.unswid value (i.e. unsw student id)
//  $semester = code for semester (e.g. "09s2")
// Outputs:
//  Virtual transcript array (see spec for details)

function progress($db, $stuID, $term)
{
  return array(); // stub
}


// Task E:

// E.g. $advice = advice($db, 3012345, 162, 164)
// Inputs:
//  $db = open database handle
//  $studentID = People.unswid value (i.e. unsw student id)
//  $currTermID = code for current semester (e.g. "09s2")
//  $nextTermID = code for next semester (e.g. "10s1")
// Outputs:
//  Advice array (see spec for details)

function advice($db, $studentID, $currTermID, $nextTermID)
{
  return array(); // stub
}

?>
