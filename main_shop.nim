import parsecsv  # используйте для чтения ваших csv файлов
import db_connector/db_sqlite  # или norm/[model, sqlite]
import os
import strutils
import times


#import sugar

type
  ## Реализуйте объекты для магазина
  Post = enum
    NONE, Кассир, Уборщик, Консультант, Менеджер, Директор

  Staff = ref object of RootObj
    firstName: string
    lastName: string
    birthDate: int64
    post: Post

  Good = ref object of RootObj
    title: string
    price: float
    endDate: int64
    discount: float
    count: int

  Cash = ref object of RootObj
    number: int
    free: bool
    totalCash: float
                          
var sqStaffs : seq[Staff]
var sqGoods : seq[Good]
var sqCashs : seq[Cash]

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
        let staffItem = Staff(firstName:csv.rowEntry(csv.headers[0]),
                lastName:csv.rowEntry(csv.headers[1]),
                birthDate: DtToUnix(csv.rowEntry(csv.headers[2])),
                post: ReadPost(csv.rowEntry(csv.headers[3])))
        sqStaffs.add(staffItem) 
    of "GOODS":                 
      while csv.readRow:    
        let goodItem = Good(title:csv.rowEntry(csv.headers[0]),
                price:(csv.rowEntry(csv.headers[1]).parseFloat),
                endDate: DtToUnix(csv.rowEntry(csv.headers[2])),
                discount: csv.rowEntry(csv.headers[3]).parseFloat,
                count: csv.rowEntry(csv.headers[4]).parseInt                
                )
        sqGoods.add(goodItem)        
    of "CASHS":                 
      while csv.readRow:    
        let cashItem = Cash(number:csv.rowEntry(csv.headers[0]).parseInt,
                free:(csv.rowEntry(csv.headers[1]).parseBool),                
                totalCash: csv.rowEntry(csv.headers[2]).parseFloat          
                )
        sqCashs.add(cashItem)        
        
  finally:
    csv.close()
        

# Создайте таблицы в базе данных.
# Реализуйте загрузку экземпляра объекта в соответствующую таблицу.

when isMainModule:
  let db = open("shop.db", "", "", "")
         
  db.exec(sql"""CREATE TABLE IF NOT EXISTS STAFFS (
               firstName   varchar(60) NOT NULL,
               lastName   varchar(60) NOT NULL,
               birthDate date NOT NULL,
               post varchar(20) NOT NULL
            )""")
              
  db.exec(sql"""CREATE TABLE IF NOT EXISTS GOODS (
               title   varchar(120) NOT NULL,
               price   numeric(15,2) NOT NULL,
               endDate date NOT NULL,
               discount numeric(15,2) NOT NULL DEFAULT 0,
               count integer NOT NULL
            )""")  
            
  db.exec(sql"""CREATE TABLE IF NOT EXISTS CASHS (
               number integer NOT NULL,
               free integer NOT NULL,
               totalCash numeric(15,2) NOT NULL
            )""")                

  #Очистить таблицы      
  db.exec(sql"BEGIN")              
  db.exec(sql"""DELETE FROM STAFFS""")
  db.exec(sql"""DELETE FROM GOODS""")
  db.exec(sql"""DELETE FROM CASHS""")                 
  db.exec(sql"COMMIT")
            
  insSql = readCsv(getAppDir() / "data" / "shop_staff.csv","STAFFS")
      
  if sqStaffs.len!=0:      
    for staffItem in sqStaffs:
      db.exec(sql"BEGIN")
      var insertStmt = db.prepare(insSql)
      try:
        insertStmt.bindParams(staffItem.firstName,staffItem.lastName,staffItem.birthDate, $staffItem.post)            
        let bres = db.tryExec(insertStmt)                    
        finalize(insertStmt)
      except DbError as e:
        echo "Ошибка базы данных: ", e.msg
      db.exec(sql"COMMIT")              
    
  insSql = readCsv(getAppDir() / "data" / "shop_goods.csv","GOODS")
              
  if sqGoods.len!=0:        
    db.exec(sql"BEGIN")  
    for goodItem in sqGoods:
      var insertStmt = db.prepare(insSql)
      try:
        insertStmt.bindParams(goodItem.title,goodItem.price,goodItem.endDate, goodItem.discount, goodItem.count)
        let bres = db.tryExec(insertStmt)
        finalize(insertStmt)          
      except DbError as e:
        echo "Ошибка базы данных: ", e.msg  
    db.exec(sql"COMMIT")              
  
  insSql = readCsv(getAppDir() / "data" / "shop_cashes.csv","CASHS")
      
  if sqCashs.len!=0: 
    db.exec(sql"BEGIN")  
    for cashItem in sqCashs:
      var insertStmt = db.prepare(insSql)    
      try:                                     
        var iBool : int
        if cashItem.free:
          iBool=1
        else: 
          iBool=0  
        insertStmt.bindParams(cashItem.number,iBool,cashItem.totalCash)      
        let bres = db.tryExec(insertStmt)
        doAssert(bres)  
        
        finalize(insertStmt)
      except DbError as e:
        echo "Ошибка базы данных: ", e.msg   
    db.exec(sql"COMMIT")                                   
            
  db.close()            
