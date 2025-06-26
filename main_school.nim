import parsecsv  # используйте для чтения ваших csv файлов
import db_connector/db_sqlite  # или norm/[model, sqlite]
import os
import strutils
import times

type
  
  Director = ref object of RootObj
    firstname : string
    lastname : string     
    
  Teacher = ref object of RootObj
    firstname : string
    lastname : string 
    class : int
  
  Student = ref object of RootObj
    firstname : string
    lastname : string 
    class : int
                             
var sqDirectors : seq[Director]    
var sqTeachers : seq[Teacher]
var sqStudents : seq[Student]

var insSql  : string
     
proc readCsv(fileName : string; tableName : string):string=
  var csv: CsvParser   
  var insSQl, insSqlDt: string;
  csv.open(fileName)
  try:               
    csv.readHeaderRow
    insSql="INSERT INTO " & tableName & "("
    insSqlDt= "VALUES("
    for i in 1 .. csv.headers.len:
      insSql=insSql & csv.headers[i-1]
      insSqlDt=insSqlDt & "?"
      if i<csv.headers.len:
        insSql=insSql & ","
        insSqlDt=insSqlDt & ","
      else:
        insSql=insSql & ")"
        insSqlDt=insSqlDt & ")"
    
    result= insSQl & insSqlDt
    case tableName  
    of "DIRECTORS":                 
      while csv.readRow:    
        let directorItem = Director(firstName:csv.rowEntry(csv.headers[0]),
                lastName:csv.rowEntry(csv.headers[1]))
        sqDirectors.add(directorItem)    
    of "TEACHERS":                 
      while csv.readRow:    
        let teacherItem = Teacher(firstName:csv.rowEntry(csv.headers[0]),
                lastName:csv.rowEntry(csv.headers[1]),
                class:csv.rowEntry(csv.headers[2]).parseInt)
        sqTeachers.add(teacherItem) 
    of "STUDENTS":                 
      while csv.readRow:    
        let studentItem = Student(firstName:csv.rowEntry(csv.headers[0]),
                lastName:csv.rowEntry(csv.headers[1]),
                class:csv.rowEntry(csv.headers[2]).parseInt              
                )
        sqStudents.add(studentItem)
        
  finally:
    csv.close()        

when isMainModule:
  let db = open("school.db", "", "", "")
         
  db.exec(sql"""CREATE TABLE IF NOT EXISTS DIRECTORS (
               firstName   varchar(60) NOT NULL,
               lastName   varchar(60) NOT NULL
            )""")
              
  db.exec(sql"""CREATE TABLE IF NOT EXISTS TEACHERS (
               firstName   varchar(60) NOT NULL,
               lastName   varchar(60) NOT NULL,               
               class integer NOT NULL
            )""")  
                 
  db.exec(sql"""CREATE TABLE IF NOT EXISTS STUDENTS (
               firstName   varchar(60) NOT NULL,
               lastName   varchar(60) NOT NULL,               
               class integer NOT NULL
            )""")              
  
  #Очистить таблицы      
  db.exec(sql"BEGIN")              
  db.exec(sql"""DELETE FROM DIRECTORS""")
  db.exec(sql"""DELETE FROM TEACHERS""")
  db.exec(sql"""DELETE FROM STUDENTS""")                 
  db.exec(sql"COMMIT")
            
  insSql = readCsv(getAppDir() / "data" / "school_Director.csv","DIRECTORS")
      
  if sqDirectors.len!=0:      
    for directorItem in sqDirectors:
      db.exec(sql"BEGIN")
      var insertStmt = db.prepare(insSql)
      try:
        insertStmt.bindParams(directorItem.firstName,directorItem.lastName)            
        let bres = db.tryExec(insertStmt)                    
        finalize(insertStmt)
      except DbError as e:
        echo "Ошибка базы данных: ", e.msg
      db.exec(sql"COMMIT")              
    
  insSql = readCsv(getAppDir() / "data" / "school_Teacher.csv","TEACHERS")
              
  if sqTeachers.len!=0:        
    db.exec(sql"BEGIN")  
    for teacherItem in sqTeachers:
      var insertStmt = db.prepare(insSql)
      try:
        insertStmt.bindParams(teacherItem.firstname,teacherItem.lastName,teacherItem.class)
        let bres = db.tryExec(insertStmt)
        finalize(insertStmt)          
      except DbError as e:
        echo "Ошибка базы данных: ", e.msg  
    db.exec(sql"COMMIT")              
  
  insSql = readCsv(getAppDir() / "data" / "school_Student.csv","STUDENTS")
      
  if sqStudents.len!=0: 
    db.exec(sql"BEGIN")  
    for studentItem in sqStudents:
      var insertStmt = db.prepare(insSql)    
      try:
        insertStmt.bindParams(studentItem.firstname,studentItem.lastName,studentItem.class)      
        let bres = db.tryExec(insertStmt)
        doAssert(bres)  
        
        finalize(insertStmt)
      except DbError as e:
        echo "Ошибка базы данных: ", e.msg   
    db.exec(sql"COMMIT")                                   
            
  db.close()