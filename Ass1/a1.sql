-- COMP3311 18s1 Assignment 1
-- Written by Mehri Amin (z5113067), April 2018

-- Q1: Define a SQL view that gives the STUDENT_ID and NAME of any student who
--     has studies MORE THAN 65 courses at UNSW.

create or replace view Q1(unswid, name)
as
  SELECT p.unswid AS unswid, p.name AS name FROM people p 
    JOIN course_enrolments c ON (p.id = c.student)
  GROUP BY p.unswid, p.name
    HAVING count(*) > 65
;

-- Q2: SQL view that produces a table that contains count of
--     a) total number of students who are also not staff
--     b) total number of staff who are also not students
--     c) total number of people who are both staff and student

-- Helper view for a)
create or replace view _nstudents(nstudent)
as
  SELECT count(*) AS nstudent FROM
    (SELECT s.id FROM Students s EXCEPT SELECT st.id FROM Staff st)
    AS _nstudents
;
-- Helper view for b)
create or replace view _nstaff(nstaff)
as
  SELECT count(*) AS nstaff FROM
    (SELECT st.id FROM Staff st EXCEPT SELECT s.id FROM Students s)
    AS _nstaff
;

-- Helper view for c)
create or replace view _nboth(nboth)
as
  SELECT count(*) AS nboth FROM
    (SELECT s.id FROM Students s INTERSECT SELECT st.id FROM Staff st)
    AS _nboth
;

-- Q2: returns table that contains all 3 parameters
create or replace view Q2(nstudents, nstaff, nboth)
as
  SELECT * FROM _nstudents, _nstaff, _nboth
;

-- Q3
-- Helper view for Q3 to get list of course conveyors
create or replace view _course_conveyor(name, ncourses)
as
  SELECT p.name AS name, count(p.name) AS ncourses FROM People p
    JOIN Course_staff cs ON (cs.staff = p.id) -- gets people who are course_staff
    JOIN Staff_roles sr ON (sr.id =cs.role) -- gets people who are LIC
      WHERE sr.name = 'Course Convenor'
  GROUP BY p.name -- group by people
;

-- Q3: SQL view that prints the name of person and number of courses 
--     of LIC who has taught the most courses at UNSW.
--     LIC = "Course Convenor".
create or replace view Q3(name, ncourses)
as
  SELECT c.name, c.ncourses FROM _course_conveyor c
    WHERE c.ncourses = (SELECT max(ncourses) FROM _course_conveyor) -- gets person with most courses taught as a course convenor.
;

-- Q4: Give Student IDS of...

-- 4a) Students enrolled in 05s2 Computer Science (3978) Degree
create or replace view Q4a(id)
as
  SELECT p.unswid FROM People p
    JOIN Students s ON (s.id = p.id)
    JOIN Program_enrolments pe ON (pe.student = s.id)
    JOIN Programs prog ON (prog.id = pe.program)
    JOIN Semesters sem ON (sem.id = pe.semester)
  WHERE sem.year = '2005' AND sem.term = 'S2' AND prog.code = '3978'
;

-- 4b) Students enrolled in 05s2 Software Engineering (SENGA1) Stream
create or replace view Q4b(id)
as
  SELECT p.unswid FROM People p
    JOIN Students s ON (s.id = p.id)
    JOIN Program_enrolments pe ON (pe.student = s.id)
    JOIN Stream_enrolments se ON (se.partOf = pe.id)
    JOIN Streams str ON (str.id = se.stream)
    JOIN Semesters sem ON (sem.id = pe.semester)
  WHERE sem.year = '2005' AND sem.term = 'S2' AND str.code = 'SENGA1'
;

-- 4c) Students enrolled in 05s2 in degrees offered by CSE
create or replace view Q4c(id)
as
  SELECT p.unswid FROM People p
    JOIN Students s ON (s.id = p.id)
    JOIN Program_enrolments pe ON (pe.student = s.id)
    JOIN Programs prog ON (prog.id = pe.program)
    JOIN OrgUnits org ON (org.id = prog.offeredBy)
    JOIN Semesters sem ON (sem.id = pe.semester)
    WHERE sem.year = '2005' AND sem.term = 'S2' AND org.name LIKE '%Computer Science and Engineering%'
;

-- Q5...
-- Helper view gets list of committees
create or replace view _committee(id)
as
  SELECT facultyOf(o.id) FROM OrgUnits o
    JOIN OrgUnit_types ot ON (ot.id = o.utype)
    WHERE ot.name = 'Committee'
;

--Q5...
-- Helper view that counts committees then groups them
create or replace view _count_committees(id, ncount)
as
  SELECT c.id AS id, count(c.id) AS ncount FROM _committee c
    WHERE c.id is NOT null
    GROUP BY c.id
;

-- Q5: SQL view that gives faculty that has max number of committees. 
create or replace view Q5(name)
as
  SELECT o.name AS name FROM OrgUnits o
    JOIN _count_committees max ON (max.ncount = (SELECT max(ncount) FROM _count_committees))
    WHERE max.id = o.id
;

-- Q6: SQL function that takes a parameter that is either people.id OR people.unswid
--     and return the name of that person. Return empty result if id value is invalid. 

create or replace function Q6(integer) returns text
as
$$
  SELECT p.name FROM People p
    WHERE p.id = $1 OR p.unswid = $1
$$ language sql
;

-- Q7: SQL function that takes UNSW course code as parameter and returns list of all
--     offerings of the course where a course convenor is known.

create or replace function Q7(text)
	returns table (course text, year integer, term text, convenor text)
as $$
 SELECT $1, sem.year, CAST(sem.term as text), p.name FROM subjects subj
    JOIN courses c ON (c.subject=subj.id)
    JOIN semesters sem ON (sem.id=c.semester)
    JOIN course_staff cs ON (cs.course=c.id)
    JOIN staff_roles sr ON (sr.id=cs.role)
    JOIN people p ON (cs.staff=p.id)
  WHERE subj.code = $1 AND sr.name = 'Course Convenor'
$$ language sql
;

-- Q8: return a new kind of transcript record that includes in each row except that last
--     the 4-digit program code for the program being studied when the course was studied.

create or replace function Q8(integer)
	returns setof NewTranscriptRecord
as $$
declare
  rec NewTranscriptRecord;
  UOCtotal integer := 0;
  UOCpassed integer := 0;
  wsum integer := 0;
  wam integer := 0;
  x integer;
begin
  select s.id into x
    from Students s join People p on (s.id = p.id)
    where p.unswid = $1; -- function argument -- CODE HERE
    if (not found) then
      raise EXCEPTION 'Invalid student %',$1;
    end if;
    for rec in
      select su.code,
              substr(t.year::text,3,2)||lower(t.term),
              prog.code, -- 4-digit program code -- CODE HERE
              substr(su.name,1,20),
              e.mark, e.grade, su.uoc
      from People p
        join Students s on (p.id = s.id)
        join Course_enrolments e on (e.student = s.id)
        join Courses c on (c.id = e.course)
        join Subjects su on (c.subject = su.id)
        join Semesters t on (c.semester = t.id)
      -- join program -- CODE HERE
      join program_enrolments pe on (pe.student = s.id) AND (pe.semester = t.id) --CODE HERE
      join programs prog on (prog.id = pe.program) --CODE HERE
      where  p.unswid = $1 -- given student id -- CODE HERE
      order by t.starting, su.code 
    loop
      if (rec.grade = 'SY') then
        UOCpassed := UOCpassed + rec.uoc;
      elsif (rec.mark is not null) then
        if (rec.grade in ('PT','PC','PS','CR','DN','HD','A','B','C')) then
          -- only counts towards creditted UOC
          -- if they passed the course
          UOCpassed := UOCpassed + rec.uoc;
        end if;
        -- we count fails towards the WAM calculation
        UOCtotal := UOCtotal + rec.uoc;
        -- weighted sum based on mark and uoc for course
        wsum := wsum + (rec.mark * rec.uoc);
        -- don't give UOC if they failed
        if (rec.grade not in ('PT','PC','PS','CR','DN','HD','A','B','C')) then
          rec.uoc := 0;
        end if;
      end if;
      return next rec;
    end loop;
    if (UOCtotal = 0) then
      rec := (null,null,null,'No WAM available',null,null,null);
    else
      wam := wsum / UOCtotal;
      rec := (null,null,null,'Overall WAM',wam,null,UOCpassed);
    end if;
    -- append the last record containing the WAM
    return next rec;
end;
$$ language plpgsql
;



-- Q9: write a function that takes the id of an aog and returns the codes
--     for all members of the aog. only consider groups defined via a pattern.
--     else return empty result.
create or replace function Q9(integer)
	returns setof AcObjRecord
as $$
declare
  rec AcObjRecord; -- returnValue
  obj_type text; -- what kind of objects are in this group? (subject, stream or program)
  obj_defby text; -- how is the group defined?
  obj_def text; -- pattern to define these objects
  aog_code char(8); -- code we need to return
  pattern text; -- pattern variable
  var text; -- variable
begin

  SELECT acad_object_groups.gtype, acad_object_groups.gdefby, acad_object_groups.definition
    INTO obj_type, obj_defby, obj_def
    FROM acad_object_groups
    WHERE acad_object_groups.id = $1;

  -- only considering groups definied via  pattern, if not return empty result
  IF obj_defby NOT LIKE 'pattern' THEN RETURN;
  END IF;
  
  -- you can ignore patterns for FREE#### and GENG##### and constraint clauses like
  -- {MATH1131;MATH1141} also ZGEN####
  IF obj_def SIMILAR TO '%{\w+;\w+}%' OR obj_def SIMILAR TO '%(FREE|GENG|ZGEN)%'
    THEN RETURN;
  END IF;

  -- remove spaces and replace # with word character regex's in pattern
  pattern = replace(replace(obj_def, '#', '\w'), ' ', '');
  
  -- get the object that the pattern is made of
  FOR var IN SELECT * FROM regexp_split_to_table(pattern, ',')
  LOOP
    -- SUBJECT
    IF obj_type = 'subject' THEN
        FOR aog_code IN 
            SELECT DISTINCT su.code FROM Subjects su
            WHERE su.code SIMILAR TO var
            ORDER BY su.code
        LOOP
            rec := (obj_type, aog_code);
            RETURN next rec;
        END LOOP;
    
    -- STREAM
    ELSIF obj_type = 'stream' THEN
        FOR aog_code IN 
            SELECT DISTINCT st.code
            FROM Streams st
            WHERE st.code SIMILAR TO var
            ORDER BY st.code
        LOOP
            rec := (obj_type, aog_code);
            RETURN next rec;
        END LOOP;

    -- PROGRAM
    ELSIF obj_type = 'program' THEN
        FOR aog_code IN
            SELECT DISTINCT pg.code
            FROM Programs pg
            WHERE pg.code SIMILAR TO var
            ORDER BY pg.code
        LOOP
            rec := (obj_type, aog_code);
            RETURN next rec;
        END LOOP;

    ELSE RETURN;

    END IF;

  END LOOP;

END;

$$ language plpgsql
;

