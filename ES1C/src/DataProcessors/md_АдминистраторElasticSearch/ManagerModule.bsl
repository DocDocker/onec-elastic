#Если ТолстыйКлиентОбычноеПриложение ИЛИ Сервер ИЛИ ВнешнееСоединение Тогда
    
#Область ПрограммныйИнтерфейс

Функция ЗаполнитьДеревоВерсийПоОбъекту(ПараметрыПостроения) Экспорт
    
    СтруктураРезультат = Новый Структура;
    
    ИндексES = ПараметрыПостроения.ИндексES;
    АдресСервера = ПараметрыПостроения.АдресСервера;
    ПортСервера = ПараметрыПостроения.ПортСервера;
	ДеревоОбъектов = ПараметрыПостроения.ДеревоОбъектов;
    ДатаОтбора = ПараметрыПостроения.ДатаОтбора;
    ВсегоВерсий = ПараметрыПостроения.ВсегоВерсий;
    СсылкаНаОбъект = ПараметрыПостроения.СсылкаНаОбъект;
    
	ЗаголовкиЗапроса = Новый Соответствие;
	ЗаголовкиЗапроса.Вставить("Content-Type", "application/json");
    
    СтруктураОтправкиПакета = Новый Структура("АдресСервера, Порт", АдресСервера, ПортСервера);
    
	АдресРесурса = md_СтроковыеФункцииКлиентСервер.ПодставитьПараметрыВСтроку("/%1/_search", 
	md_ОбщегоНазначения.ЗначениеРеквизитаОбъекта(ИндексES, "Имя"));
    
    ДанныеЗапроса = 
    "{
    |  ""query"": {
    |    ""bool"": {
    |      ""must"": {
    |        ""term"": { ""Object_ID"" : ""%УИД%"" }
    |      },
    |      ""filter"" : {
    |        ""range"" : {
    |          ""Object_DateTime"":{""%ВидСравнения%"":""%ДатаОтбора%"" }
    |        }
    |      }
    |    }
    |  },
    |  ""size"": %NumberVer%,
    |  ""sort"" : [{ ""Object_DateTime"" : ""desc"", ""Object_Version.keyword"" : ""desc"" }]
    |}";
    
	УИД = СтрЗаменить(Строка(СсылкаНаОбъект.УникальныйИдентификатор()), "-", "");
	ДанныеЗапроса = СтрЗаменить(ДанныеЗапроса, "%УИД%", УИД);	
	ДанныеЗапроса = СтрЗаменить(ДанныеЗапроса, "%NumberVer%", ВсегоВерсий);	
    ДанныеЗапроса = СтрЗаменить(ДанныеЗапроса, "%ДатаОтбора%", Формат(ДатаОтбора, "ДФ=yyyy-MM-ddTHH:mm:ssZ"));	 
    ДанныеЗапроса = СтрЗаменить(ДанныеЗапроса, "%ВидСравнения%", ?(ВидСравнения = "Больше или равно", "gte", "lte"));	
	
	СтруктураОтправкиПакета.Вставить("Заголовки", ЗаголовкиЗапроса);
	СтруктураОтправкиПакета.Вставить("АдресРесурса", АдресРесурса);
	СтруктураОтправкиПакета.Вставить("HTTPМетод", "POST");
	СтруктураОтправкиПакета.Вставить("ВидОперации", "Версии объекта");
	СтруктураОтправкиПакета.Вставить("ТелоЗапроса", ДанныеЗапроса);
	СтруктураОтправкиПакета.Вставить("УникальныйИдентификатор", Новый УникальныйИдентификатор);
	
	ОтветES = md_ОбщегоНазначенияElasticsearch.ВыполнитьЗапросКElasticSearch(СтруктураОтправкиПакета);

    НижнийПределУспешныйКодОтвета = 200;
    ВерхнийПределУспешныйКодОтвета = 300;
    
    Если ОтветES.КодСостояния >= НижнийПределУспешныйКодОтвета 
        И ОтветES.КодСостояния < ВерхнийПределУспешныйКодОтвета Тогда

		ПреобразоватьОтветESВЛеревоЗначений(ДеревоОбъектов, ОтветES.ТелоОтвета);
	   	ПоказатьИзмененияВДереверВерсий(ДеревоОбъектов);
        СтруктураРезультат.Вставить("ДеревоОбъектов", ДеревоОбъектов);
		
    Иначе
        
        ШаблонОтвета = "Код состояния: %1. Тело ответа: %2";
        
        СтрокаИнформирования = md_СтроковыеФункцииКлиентСервер.ПодставитьПараметрыВСтроку(
        ШаблонОтвета, ОтветES.КодСостояния, ОтветES.ТелоОтвета);
        
        md_ВерсионированиеElasticsearchВызовСервера.ЗафиксироватьСобытиеИнтеграцииСElasticsearch(
        УровеньЖурналаРегистрации.Ошибка, Неопределено, СтрокаИнформирования); 
        
        СтруктураРезультат.Вставить("ЕстьОшибки", Истина);
        
	КонецЕсли; 
    
    Возврат СтруктураРезультат;
    
КонецФункции

#КонецОбласти 

#Область СлужебныеПроцедурыИФункции

Процедура ПоказатьИзмененияВДереверВерсий(ДеревоОбъектов)
	
	ВерсийКОбработке = ДеревоОбъектов.Колонки.Количество() - ОбязательныеКолонкиДрева().Количество();
	
	Для каждого ВеткаДрева Из ДеревоОбъектов.Строки Цикл
	
		ОтразитьИзмененияВВеткеДрева(ВеткаДрева, ВерсийКОбработке);	
	
	КонецЦикла; 
	
КонецПроцедуры

Процедура ОтразитьИзмененияВВеткеДрева(ВеткаДрева, ВерсийКОбработке, ВеткаРодитель = Неопределено)

	Если ВеткаДрева.Строки.Количество() = 0  Тогда
		
		ПроверитьВеткуНаИзменения(ВеткаДрева, ВерсийКОбработке);
		
		Если Не ВеткаРодитель = Неопределено и ВеткаДрева.ЕстьИзменения Тогда
		
		 	ВеткаРодитель.ЕстьИзменения = Истина;
			
		КонецЕсли; 
		
	Иначе
		
		Для каждого СтрокаВетки Из ВеткаДрева.Строки Цикл
			
			ОтразитьИзмененияВВеткеДрева(СтрокаВетки, ВерсийКОбработке, ВеткаДрева);	
			
			Если Не ВеткаРодитель = Неопределено И ВеткаДрева.ЕстьИзменения Тогда
		
		 		ВеткаРодитель.ЕстьИзменения = Истина;
			
			КонецЕсли; 

		КонецЦикла;
		
	КонецЕсли; 

КонецПроцедуры

Процедура ПроверитьВеткуНаИзменения(ВеткаДрева, ВерсийКОбработке)

	ШаблонИмени = "Версия%1";
	
	Для i = 1 По ВерсийКОбработке  Цикл
		ИмяВерсии = md_СтроковыеФункцииКлиентСервер.ПодставитьПараметрыВСтроку(ШаблонИмени, Формат(i, "ЧГ="));
		ЗначениеСравнения = ВеткаДрева[ИмяВерсии];
		
		Для j = i + 1 По ВерсийКОбработке Цикл
			
			ИмяВерсииСравнения = md_СтроковыеФункцииКлиентСервер.ПодставитьПараметрыВСтроку(ШаблонИмени, Формат(j, "ЧГ="));
			
			Если НЕ ЗначениеСравнения = ВеткаДрева[ИмяВерсииСравнения] Тогда
				
				ВеткаДрева.ЕстьИзменения = Истина;
				Прервать;
					
			КонецЕсли;
			
		КонецЦикла;
		
		Если ВеткаДрева.ЕстьИзменения Тогда
			
			Прервать;		
			
		КонецЕсли;
		
	КонецЦикла; 

КонецПроцедуры

Процедура ПреобразоватьОтветESВЛеревоЗначений(ДеревоОбъектов, ДанныеДокументов)
	
	ЧтениеJSON = Новый ЧтениеJSON;
	ЧтениеJSON.УстановитьСтроку(ДанныеДокументов);
	
	Версия = 0;
	Пока ЧтениеJSON.Прочитать() Цикл
		
		Если ЧтениеJSON.ТипТекущегоЗначения = ТипЗначенияJSON.ИмяСвойства И ЧтениеJSON.ТекущееЗначение = "_source" Тогда
			
			СтруктураДокумента = ПреобразоватьДокументJSONВСтруктуру(ПрочитатьJSON(ЧтениеJSON, Истина));
			
			Версия = Версия + 1;
			
			Для каждого ЭлементДокументаJSON Из СтруктураДокумента Цикл
				
				СформироватьВерсиюОбъектаВДереве(ЭлементДокументаJSON.Ключ, 
                                                            ЭлементДокументаJSON.Значение, 
                                                            ДеревоОбъектов, Версия);
												
			КонецЦикла;
			
		КонецЕсли; 
		
	КонецЦикла;

КонецПроцедуры

Процедура ОбработатьДобавлениеМассиваВДерево(ИмяЭлемента, ЗначениеЭлемента, ВеткаДереваОбъектов, Версия)

	СтрокаВетки = СоздатьПолучитьСтрокуВеткиПоКлючу(ИмяЭлемента, ВеткаДереваОбъектов);	
	
	Для Каждого СтрокаКоллеции Из ЗначениеЭлемента Цикл
		
		СформироватьВерсиюОбъектаВДереве(СтрокаКоллеции.Ключ, СтрокаКоллеции.Значение, СтрокаВетки, Версия);	
		
	КонецЦикла;
	
КонецПроцедуры

Процедура ОбработатьДобавлениеСтруктурыВДрево(ИмяЭлемента, ЗначениеЭлемента, ВеткаДереваОбъектов, Версия)
		
	СтрокаВетки = СоздатьПолучитьСтрокуВеткиПоКлючу(ИмяЭлемента, ВеткаДереваОбъектов);
	
	Для каждого ЭлементКоллекции Из ЗначениеЭлемента Цикл
	
		СформироватьВерсиюОбъектаВДереве(ЭлементКоллекции.Ключ, ЭлементКоллекции.Значение, СтрокаВетки,Версия);	
	
	КонецЦикла; 
		
КонецПроцедуры

Процедура СформироватьВерсиюОбъектаВДереве(ИмяЭлемента, ЗначениеЭлемента, ВеткаДереваОбъектов, Версия)
	
	ТипЗначенияЭлементаДокумента = ТипЗнч(ЗначениеЭлемента);
	
	Если ТипЗначенияЭлементаДокумента = Тип("Структура") Тогда
		
		ОбработатьДобавлениеСтруктурыВДрево(ИмяЭлемента, ЗначениеЭлемента, ВеткаДереваОбъектов, Версия);
				
	ИначеЕсли ТипЗначенияЭлементаДокумента = Тип("Массив") Тогда
		
		ОбработатьДобавлениеМассиваВДерево(ИмяЭлемента, ЗначениеЭлемента, ВеткаДереваОбъектов, Версия); 
		
	Иначе
		
		СтрокаРеквизит = СоздатьПолучитьСтрокуВеткиПоКлючу(ИмяЭлемента, ВеткаДереваОбъектов);
		СтрокаРеквизит["Версия" + Формат(Версия, "ЧГ=")] = ЗначениеЭлемента;
	
	КонецЕсли;
	
КонецПроцедуры

Функция СоздатьПолучитьСтрокуВеткиПоКлючу(ИмяКолонки, ВеткаДереваОбъектов)
	
	СтрокаВетки = ВеткаДереваОбъектов.Строки.Найти(ИмяКолонки,"Реквизит");
	
	Если СтрокаВетки = Неопределено Тогда
		
		СтрокаВетки = ВеткаДереваОбъектов.Строки.Добавить();
		СтрокаВетки.Реквизит = ИмяКолонки;		
		
	КонецЕсли; 
	
	Возврат СтрокаВетки;	

КонецФункции // ()

#Область ПреобразованиеJSON

Процедура ЗаполнитьСтруктуруПоДокументуJSON(СтруктураДокументJSON, ДокументJSON, ГруппыРеквизитов = Неопределено)

	ИмяГруппы = "ДанныеДокумента";
	
	Для каждого ЭлементДокумента Из ДокументJSON Цикл
		
		Если ЗначениеЗаполнено(ГруппыРеквизитов) Тогда
			
			Для каждого ГруппаРеквизитов Из ГруппыРеквизитов Цикл
				
				Если НЕ ГруппаРеквизитов.Описание.Найти(ЭлементДокумента.Ключ) = Неопределено Тогда
					
					ИмяГруппы = ГруппаРеквизитов.ИмяГруппы; 	
					Прервать;
					
				КонецЕсли; 
				
			КонецЦикла; 			
			
		КонецЕсли; 
					
		Если Не СтруктураДокументJSON.Свойство(ИмяГруппы) Тогда
			
			СтруктураДокументJSON.Вставить(ИмяГруппы, Новый Структура);
			
		КонецЕсли;
		
		ПреобразоватьСвойствоВСтруктуруДокумента(СтруктураДокументJSON[ИмяГруппы], 
                                                 ЭлементДокумента.Ключ, 
                                                 ЭлементДокумента.Значение);
		
	КонецЦикла;
	
КонецПроцедуры

Процедура ПреобразоватьСвойствоВСтруктуруДокумента(СтруктураДокумент, Знач ИмяСвойства, ЗначениеСвойство, Префикс = "")
    
	Если ТипЗнч(ЗначениеСвойство) = Тип("Массив") Тогда //Табличная часть
		
		СтруктураДокумент.Вставить(ИмяСвойства, Новый Массив);
		
		i = 1;
		
		Для Каждого ЭлементКоллекции Из ЗначениеСвойство Цикл
			
			ЗначениеКлюча = md_СтроковыеФункцииКлиентСервер.ПодставитьПараметрыВСтроку("Строка%2", 
            ИмяСвойства, i);
            
			СтруктураСтроки = Новый Структура("Ключ,Значение", ЗначениеКлюча, Новый Структура);
			
			Для Каждого АтрибутКоллеции Из ЭлементКоллекции Цикл
				
				ПреобразоватьСвойствоВСтруктуруДокумента(СтруктураСтроки.Значение, АтрибутКоллеции.Ключ, 
                АтрибутКоллеции.Значение, ЗначениеКлюча);
				
			КонецЦикла; 
			
			СтруктураДокумент[ИмяСвойства].Добавить(СтруктураСтроки);
			i = i + 1;
			
		КонецЦикла; 	
		
	ИначеЕсли ТипЗнч(ЗначениеСвойство) = Тип("Соответствие") Тогда //Составной тип
                
		СтруктураДокумент.Вставить(ИмяСвойства, Новый Структура);

		Для Каждого ОписаниеТипа Из ЗначениеСвойство Цикл
			
			Если ОписаниеТипа.Ключ = "#type" Тогда
                
                ИмяКлюча = "type";
							
			ИначеЕсли ОписаниеТипа.Ключ = "#value" Тогда
                
                ИмяКлюча = "value";
				
			Иначе
                
                ИмяКлюча = ОписаниеТипа.Ключ;
					
			КонецЕсли;
            
            СтруктураДокумент[ИмяСвойства].Вставить(ИмяКлюча, ОписаниеТипа.Значение);

		КонецЦикла; 
		
	Иначе
         
		СтруктураДокумент.Вставить(ИмяСвойства, ЗначениеСвойство);
		
	КонецЕсли; 

КонецПроцедуры
 
Функция ПреобразоватьДокументJSONВСтруктуру(Знач ДокументJSON)
	
	Перем ДанныеДокументаJSON;
	
	ГруппыСлужебныхРеквизитов = ПолучитьГруппыСлужебныхРеквизитов();
	СтруктураДокументJSON = Новый Структура;
		
	Если НЕ ДокументJSON["DataFields"] = Неопределено Тогда
		
		ДанныеДокументаJSON = ДокументJSON["DataFields"].Получить("#value");
		ДокументJSON.Удалить("DataFields");
		
	КонецЕсли; 
	
	ЗаполнитьСтруктуруПоДокументуJSON(СтруктураДокументJSON, ДокументJSON, ГруппыСлужебныхРеквизитов);
	
	Если ЗначениеЗаполнено(ДанныеДокументаJSON) Тогда
		
		ЗаполнитьСтруктуруПоДокументуJSON(СтруктураДокументJSON, ДанныеДокументаJSON);	
		
	КонецЕсли; 
	
	Возврат СтруктураДокументJSON;
		
КонецФункции

#КонецОбласти 

#Область СлужебныеРеквизиты

Функция ПолучитьМассивНеобязательныхРеквизитов() Экспорт

	МассивНеобязательныхРеквизитов = Новый Массив;
	МассивНеобязательныхРеквизитов.Добавить("#type");
	МассивНеобязательныхРеквизитов.Добавить("#value");

	Возврат МассивНеобязательныхРеквизитов;

КонецФункции

Функция ПолучитьГруппыСлужебныхРеквизитов() Экспорт

	ГруппыСлужебныхРеквизитов = Новый Массив;
	
	МассивНеобязательныхРеквизитов = Новый Массив;
	МассивНеобязательныхРеквизитов.Добавить("Object_ID");
	МассивНеобязательныхРеквизитов.Добавить("Metadata_FullName");
	МассивНеобязательныхРеквизитов.Добавить("Metadata_Name");
	МассивНеобязательныхРеквизитов.Добавить("Object_Version");
	МассивНеобязательныхРеквизитов.Добавить("Object_DateTime");	
	МассивНеобязательныхРеквизитов.Добавить("Object_User");
	                                                    	
	ГруппыСлужебныхРеквизитов.Добавить(Новый Структура("ИмяГруппы, Описание", "СлужебныеДанные", МассивНеобязательныхРеквизитов));	
	
	Возврат ГруппыСлужебныхРеквизитов;

КонецФункции

Функция ОбязательныеКолонкиДрева()

	МассивОбязательныхКолонок = Новый Массив;
	МассивОбязательныхКолонок.Добавить("Реквизит");
	МассивОбязательныхКолонок.Добавить("ЕстьИзменения");
	
	Возврат МассивОбязательныхКолонок;
	
КонецФункции 

#КонецОбласти 
 
#КонецОбласти 

#КонецЕсли 

