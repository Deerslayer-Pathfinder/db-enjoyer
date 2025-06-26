import parsecsv  # используйте для чтения ваших csv файлов
import db_connector/db_sqlite  # или norm/[model, sqlite]
import os
import strutils
import times

type

  Post = enum
    NONE, Директор, Секретарь, Бухгалтер

  Staff = ref object of RootObj    
    name: string
    birthDate: int64
    uid : int
  
  Manager = ref object of RootObj
      name : string 
      post : Post

  Pet = ref object of RootObj
      name : string
      age : int
                          
var sqStaffs : seq[Staff]
var sqManagers : seq[Manager]
var sqPets : seq[Pet]

var insSql  : string
     
proc ReadPost(post: string):Post =
  try:
    parseEnum[Post](post)
  except ValueError:
    stderr.write("Нет такой должности $1\n" % post)
    NONE
                       
proc DtToUnix(date: string): int64 =
  try:
    return date.parse("dd'.'MM'.'YYYY").toTime.toUnix
  except TimeParseError:
    stderr.write(getCurrentExceptionMsg() & "\n")
    return result
    
# Реализуйте функции чтения и преобразования csv записи
# в соответствующий объект или модель.
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
    of "STAFFS":                 
      while csv.readRow:    
        let staffItem = Staff(name:csv.rowEntry(csv.headers[0]),                
                birthDate: DtToUnix(csv.rowEntry(csv.headers[1])),
                uid: csv.rowEntry(csv.headers[2]).parseInt)
        sqStaffs.add(staffItem) 
    of "MANAGERS":                 
      while csv.readRow:    
        let managerItem = Manager(name:csv.rowEntry(csv.headers[0]),
                post: ReadPost(csv.rowEntry(csv.headers[1]))                
                )
        sqManagers.add(managerItem)        
    of "PETS":                 
      while csv.readRow:    
        let petItem = Pet(name:csv.rowEntry(csv.headers[0]),
                age:(csv.rowEntry(csv.headers[1]).parseInt)          
                )
        sqPets.add(petItem)       
        
  finally:
    csv.close()
        

# Создайте таблицы в базе данных.
# Реализуйте загрузку экземпляра объекта в соответствующую таблицу.

when isMainModule:
  let db = open("shelter.db", "", "", "")
         
  db.exec(sql"""CREATE TABLE IF NOT EXISTS STAFFS (
               Name   varchar(60) NOT NULL,               
               birthDate date NOT NULL,
               uid integer NOT NULL
            )""")
              
  db.exec(sql"""CREATE TABLE IF NOT EXISTS MANAGERS (
               Name varchar(60) NOT NULL,               
               Post varchar(20) NOT NULL
            )""")  
            
  db.exec(sql"""CREATE TABLE IF NOT EXISTS PETS (
               name varchar(60) NOT NULL,
               age integer NOT NULL
            )""")                  

  #Очистить таблицы      
  db.exec(sql"BEGIN")              
  db.exec(sql"""DELETE FROM STAFFS""")
  db.exec(sql"""DELETE FROM MANAGERS""")
  db.exec(sql"""DELETE FROM PETS""")                 
  db.exec(sql"COMMIT")
            
  insSql = readCsv(getAppDir() / "data" / "shelter_staff.csv","STAFFS")
      
  if sqStaffs.len!=0:      
    for staffItem in sqStaffs:
      db.exec(sql"BEGIN")
      var insertStmt = db.prepare(insSql)
      try:
        insertStmt.bindParams(staffItem.name,staffItem.birthDate,staffItem.uid)            
        let bres = db.tryExec(insertStmt)                         
        finalize(insertStmt)
      except DbError as e:
        echo "Ошибка базы данных: ", e.msg
      db.exec(sql"COMMIT")              
    
  insSql = readCsv(getAppDir() / "data" / "shelter_manager.csv","MANAGERS")
              
  if sqManagers.len!=0:        
    db.exec(sql"BEGIN")  
    for managerItem in sqManagers:
      var insertStmt = db.prepare(insSql)
      try:
        insertStmt.bindParams(managerItem.name,$managerItem.post)
        let bres = db.tryExec(insertStmt)
        finalize(insertStmt)          
      except DbError as e:
        echo "Ошибка базы данных: ", e.msg  
    db.exec(sql"COMMIT")              
  
  insSql = readCsv(getAppDir() / "data" / "shelter_pet.csv","PETS")
    
  if sqPets.len!=0: 
    db.exec(sql"BEGIN")  
    for petItem in sqPets:
      var insertStmt = db.prepare(insSql)    
      try:
        insertStmt.bindParams(petItem.name,petItem.age)      
        let bres = db.tryExec(insertStmt)
        doAssert(bres)  
        
        finalize(insertStmt)
      except DbError as e:
        echo "Ошибка базы данных: ", e.msg   
    db.exec(sql"COMMIT")                                   
            
  db.close()            


  