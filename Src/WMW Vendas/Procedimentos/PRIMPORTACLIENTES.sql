USE [EDITORAWVWEBPRD]
GO
/****** Object:  StoredProcedure [dbo].[PRIMPORTACLIENTES]    Script Date: 21/03/2018 17:30:08 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Batch submitted through debugger: SQLQuery1.sql|7|0|C:\Users\Administrator\AppData\Local\Temp\4\~vs926A.sql
ALTER PROCEDURE [dbo].[PRIMPORTACLIENTES]
(
  @CDEMPRESA          VARCHAR(20), 
  @CDREPRESENTANTE    VARCHAR(20),
  @CDNOVOCLIENTE	  VARCHAR(20), 
  @RETORNO            VARCHAR(20) OUTPUT) 
AS
BEGIN
     
SET LANGUAGE BRAZILIAN;
     
    -- VARIAVEIS
    DECLARE @P_EXISTE_CLIENTE                     INT;
    DECLARE @P_CODIGO                             INT;
    DECLARE @P_CODPARC                            INT;
    DECLARE @P_CODCONTATO                         INT;
    DECLARE @P_AUTO                               CHAR(1);
    DECLARE @P_CODCID                             INT;
    DECLARE @P_CODBAI                             INT;
    DECLARE @P_CODEND                             INT;
    DECLARE @P_CODUF                              INT;
    DECLARE @P_NUFONE							  VARCHAR(20);
    DECLARE @P_TELEFONEALT 						  VARCHAR(20);
	DECLARE @P_ULTIMO_CODIGO                      DECIMAL(16,0);
	DECLARE @TENTATIVA							  INT = 0; 

    DECLARE @P_SYSDATE                            VARCHAR(20);
     
    -- VARIAVEIS DO CURSOR
    DECLARE @NMRAZAOSOCIAL                        VARCHAR(40);
    DECLARE @FLTIPOPESSOA                         CHAR(1);
    DECLARE @NUFONE                               VARCHAR(20);
    DECLARE @TELEFONEALT                          VARCHAR(20);
    DECLARE @DSEMAIL							  VARCHAR(100);
    DECLARE @NUCNPJ                               VARCHAR(20);
    DECLARE @NUIERG                               VARCHAR(20);
    DECLARE @DTNASCIMENTO                         VARCHAR(20);
    DECLARE @DSTIPOLOGRADOUROCOMERCIAL            VARCHAR(20);
    DECLARE @DSLOGRADOUROCOMERCIAL                VARCHAR(100);
    DECLARE @DSNUMEROLOGRADOUROCOMERCIAL          VARCHAR(20);    
    DECLARE @DSCOMPLEMENTOCOMERCIAL               VARCHAR(20);
    DECLARE @DSBAIRROCOMERCIAL                    VARCHAR(100);
    DECLARE @DSCEPCOMERCIAL                       VARCHAR(20);
    DECLARE @DSCIDADECOMERCIAL                    VARCHAR(100);
    DECLARE @CDUFCOMERCIAL                        VARCHAR(20);
    DECLARE @COMOSOUBE							  VARCHAR(20);

         
    -- VARIAVEIS PARA TRATAMENTO DE ERROS
    DECLARE @ERRORNUM                             INT;
    DECLARE @ERRORSEVERITY                        INT;
    DECLARE @ERRORMSG                             VARCHAR(4000);
         
    SET @RETORNO = 'OK';
    -- CURSOR CLIENTE
    DECLARE CURSORCLIENTE CURSOR FOR
             SELECT UPPER(CLI.NMCLIENTE), CLI.FLTIPOPESSOA, CLI.CDREPRESENTANTE, CLI.CDNOVOCLIENTE, CLI.INSCRICAO, 
					REPLACE(REPLACE(REPLACE(CLI.NUCNPJ,'.',''),'/',''),'-',''), CLI.DSTIPOLOGRADOUROCOMERCIAL, UPPER(CLI.DSLOGRADOUROCOMERCIAL), CLI.DSNUMEROLOGRADOUROCOMERCIAL, UPPER(CLI.DSCOMPLEMENTOCOMERCIAL), 
					UPPER(CLI.DSBAIRROCOMERCIAL), CLI.DSCEPCOMERCIAL,  UPPER(CLI.DSCIDADECOMERCIAL),CLI.CDUFCOMERCIAL, REPLACE(REPLACE(CLI.NUFONE,'(',''),')',''), 
					REPLACE(REPLACE(CLI.TELEFONEALT,'(',''),')',''), CLI.EMAIL, CLI.DTNASCIMENTO, CLI.COMOSOUBE
             FROM TBLVWNOVOCLIENTE CLI
             WHERE
                  (CLI.CDEMPRESA = @CDEMPRESA AND
                   CLI.CDREPRESENTANTE = @CDREPRESENTANTE
                   ) AND
                  (CLI.CDNOVOCLIENTE = @CDNOVOCLIENTE OR
				   CLI.CDNOVOCLIENTE IS NULL
                  ) AND
                  (ISNULL(CLI.FLCONTROLEERP,'X') <> 'E'
                   )
     
    OPEN CURSORCLIENTE
    FETCH NEXT FROM CURSORCLIENTE INTO @NMRAZAOSOCIAL, @FLTIPOPESSOA, @CDREPRESENTANTE, @CDNOVOCLIENTE, @NUIERG, 
									   @NUCNPJ, @DSTIPOLOGRADOUROCOMERCIAL, @DSLOGRADOUROCOMERCIAL, @DSNUMEROLOGRADOUROCOMERCIAL, @DSCOMPLEMENTOCOMERCIAL, 
									   @DSBAIRROCOMERCIAL,  @DSCEPCOMERCIAL, @DSCIDADECOMERCIAL, @CDUFCOMERCIAL, @NUFONE, 
									   @TELEFONEALT, @DSEMAIL, @DTNASCIMENTO, @COMOSOUBE
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRANSACTION;
             
        BEGIN TRY
               
        -- VERIFICA SE O CLIENTE JA ESTA CADASTRADO NO ERP (TGFPAR)        
        SELECT @P_EXISTE_CLIENTE = ISNULL(MAX(1),0) FROM TGFPAR WHERE CGC_CPF = @NUCNPJ;
   print (ISNULL(@DSCIDADECOMERCIAL,'M'));  
        IF (@P_EXISTE_CLIENTE = 0)
        BEGIN
         --   SELECT @P_CODCID = ISNULL(MAX(CODCID),0) FROM TSICEP WHERE CEP = @DSCEPCOMERCIAL;
			SELECT @P_CODCID = ISNULL(MAX(CODCID),0) FROM TSICEP WHERE CODCID = @DSCIDADECOMERCIAL;
            SELECT @P_CODUF  = ISNULL(CODUF,0)       FROM TSIUFS WHERE CODUF = @CDUFCOMERCIAL;
			print (@DSCIDADECOMERCIAL);  
        END;
        -- CADASTRO DE CIDADE
        IF (@P_CODCID = 0)
        BEGIN
        -- TENTA ACHAR A CIDADE PELO CODIGO
     --   SELECT @P_CODCID = CODCID FROM SANKHYA_PRODUCAO.SANKHYA.TSICID WHERE CODCID = UPPER(@DSCIDADECOMERCIAL) AND UF = @P_CODUF;  
     SET @P_CODCID = @DSCIDADECOMERCIAL;
     
        END;
        IF (@P_CODCID= 0)
        BEGIN
        -- BUSCA TIPO DE NUMERACAO
            SELECT @P_AUTO = AUTOMATICO FROM TGFNUM WHERE ARQUIVO = 'TSICID';
            SELECT @P_CODIGO = ULTCOD   FROM TGFNUM WHERE ARQUIVO = 'TSICID';
        
            -- NUMERACAO AUTOMATICA
            IF (@P_AUTO = 'S')
            BEGIN
						UPDATE TGFNUM SET ULTCOD = ULTCOD + 1 WHERE ARQUIVO = 'TSICID';
						SET @P_CODCID = @P_CODIGO + 1;
						-- INSERI CIDADE NA TABELA DA SANKHYA
						INSERT INTO TSICID (CODCID, UF, NOMECID, DTALTER)
														     VALUES (@P_CODCID, @P_CODUF, @DSCIDADECOMERCIAL, SYSDATETIME());
					END;
            ELSE
            BEGIN
              -- NUMERACAO MANUAL. VAI BUSCAR O MAIOR CODIGO DE CIDADE NA TABELA
              SELECT @P_CODIGO = MAX(CODCID) FROM TSICID;
              SET @P_CODCID = @P_CODIGO + 1;
              -- INSERI CIDADE NA TABELA DA SANKHYA
              INSERT INTO TSICID (CODCID, UF, NOMECID, DTALTER)
                                               VALUES (@P_CODCID, @P_CODUF, @DSCEPCOMERCIAL, SYSDATETIME());
            END;
          END; 
   --       SELECT @P_CODCID = CODCID FROM TSICID WHERE CODCID = UPPER(@DSCIDADECOMERCIAL) AND UF = @P_CODUF;   
          
		  -- CADASTRO DE BAIRRO
          IF (@DSCEPCOMERCIAL IS NOT NULL)
          BEGIN
			SELECT @P_CODBAI = ISNULL(MAX(CODBAI),0) FROM TSIBAI WHERE UPPER(NOMEBAI) = UPPER(@DSBAIRROCOMERCIAL);
		  END;       
            IF (@P_CODBAI = 0)
                BEGIN
                      -- BUSCA TIPO DE NUMERACAO
                      SELECT @P_AUTO = AUTOMATICO FROM TGFNUM WHERE ARQUIVO = 'TSIBAI';
                      SELECT @P_CODIGO = ULTCOD   FROM TGFNUM WHERE ARQUIVO = 'TSIBAI';
                      -- NUMERACAO AUTOMATICA
                      IF (@P_AUTO = 'S')
                      BEGIN
                          UPDATE TGFNUM SET ULTCOD = ULTCOD + 1 WHERE ARQUIVO = 'TSIBAI';
                          SET @P_CODBAI = @P_CODIGO + 1;
                          -- INSERI BAIRRO NA TABELA DA SANKHYA
                          INSERT INTO TSIBAI (CODBAI, NOMEBAI, DTALTER)
															VALUES (@P_CODBAI, @DSBAIRROCOMERCIAL, SYSDATETIME());
                      END;
                      ELSE
						BEGIN
                      -- NUMERACAO MANUAL. VAI BUSCAR O MAIOR CODIGO DE BAIRRO NA TABELA
                          SELECT @P_CODIGO = MAX(CODBAI) FROM TSIBAI;
                          SET @P_CODBAI = @P_CODIGO + 1;
                          -- INSERI BAIRRO NA TABELA DA SANKHYA
                          INSERT INTO TSIBAI (CODBAI, NOMEBAI, DTALTER)
														      VALUES (@P_CODBAI, @DSBAIRROCOMERCIAL, SYSDATETIME());
						END;      
                   END;
		   -- CADASTRO DE LOGRADOURO   
           IF (@DSCEPCOMERCIAL IS NOT NULL)
           BEGIN
              SELECT @P_CODEND = ISNULL(MAX(CODEND),0) FROM TSIEND WHERE UPPER(NOMEEND) = UPPER(@DSLOGRADOUROCOMERCIAL) AND UPPER(TIPO) = UPPER(@DSTIPOLOGRADOUROCOMERCIAL);
              IF ((@P_CODEND IS NULL) OR (@P_CODEND = 0))
              BEGIN
                  -- BUSCA TIPO DE NUMERACAO
                  SELECT @P_AUTO = AUTOMATICO FROM TGFNUM WHERE ARQUIVO = 'TSIEND';
                  SELECT @P_CODIGO = ULTCOD   FROM TGFNUM WHERE ARQUIVO = 'TSIEND';
                  -- NUMERACAO AUTOMATICA
                  IF (@P_AUTO = 'S')
                  BEGIN
					  UPDATE TGFNUM SET ULTCOD = ULTCOD + 1 WHERE ARQUIVO = 'TSIEND';
									  SET @P_CODEND = @P_CODIGO + 1;
									  INSERT INTO TSIEND (CODEND, NOMEEND, TIPO, DTALTER)
																		  VALUES  (@P_CODEND, @DSLOGRADOUROCOMERCIAL, @DSTIPOLOGRADOUROCOMERCIAL, SYSDATETIME());
                  END
                  ELSE
                  BEGIN
                  -- NUMERACAO MANUAL. VAI BUSCAR O MAIOR CODIGO DE ENDERECO NA TABELA
                      SELECT @P_CODEND = MAX(CODEND)+ 1 FROM TSIEND;
                      INSERT INTO TSIEND (CODEND, NOMEEND, TIPO, DTALTER)
                                                      VALUES  (@P_CODEND, @DSLOGRADOUROCOMERCIAL, @DSTIPOLOGRADOUROCOMERCIAL, SYSDATETIME());
                  END;
               END;
            END;
               
            -- INSERE LOGRADOURO NA VARIAVEL
            SET @DSNUMEROLOGRADOUROCOMERCIAL = ISNULL(@DSNUMEROLOGRADOUROCOMERCIAL,'0');
            IF @DSNUMEROLOGRADOUROCOMERCIAL = '0'
            BEGIN
               SET @DSNUMEROLOGRADOUROCOMERCIAL = 'S/N';
            END;
            ELSE
            BEGIN
               SET @DSNUMEROLOGRADOUROCOMERCIAL = @DSNUMEROLOGRADOUROCOMERCIAL;
            END;
               
            -- BUSCA TIPO DE NUMERACAO
               SELECT @P_AUTO = AUTOMATICO FROM TGFNUM WHERE ARQUIVO = 'TGFPAR';
               SELECT @P_CODIGO = ULTCOD   FROM TGFNUM WHERE ARQUIVO = 'TGFPAR';
                  
            -- NUMERACAO AUTOMATICA
            IF (@P_AUTO = 'S')
            BEGIN
                UPDATE TGFNUM SET ULTCOD = ULTCOD + 1 WHERE ARQUIVO = 'TGFPAR';
                SET @P_CODPARC = @P_CODIGO + 1;
            END;
            ELSE
            BEGIN
                -- NUMERACAO MANUAL. VAI BUSCAR O MAIOR CODIGO DE PARCEIRO NA TABELA
                SELECT @P_CODIGO = MAX(CODPARC) FROM TGFPAR;
                SET @P_CODPARC = @P_CODIGO + 1;
            END;
            
            -- Trata campo NUFONE
            IF (LEN(@NUFONE) = 11) 
            BEGIN
				SET @P_NUFONE = SUBSTRING(@NUFONE, 1, 2) + '  ' + SUBSTRING(@NUFONE, 3, 5) + '' + SUBSTRING(@NUFONE, 8,4 );
            END;
            ELSE 
            BEGIN
				SET @P_NUFONE = SUBSTRING(@NUFONE, 1, 2) + '  ' + SUBSTRING(@NUFONE, 3, 4) + '' + SUBSTRING(@NUFONE, 7,4 );
            END;
              
            -- Trata campo TELEFONEALT
            IF (LEN(@TELEFONEALT) = 11)
			BEGIN
				SET @P_TELEFONEALT = SUBSTRING(@TELEFONEALT, 1, 2) + '  ' + SUBSTRING(@TELEFONEALT, 3, 5) + '' + SUBSTRING(@TELEFONEALT, 8,4 ); 
            END;
            ELSE
            BEGIN 
				SET @P_TELEFONEALT = SUBSTRING(@TELEFONEALT, 1, 2) + '  ' + SUBSTRING(@TELEFONEALT, 3, 4) + '' + SUBSTRING(@TELEFONEALT, 7,4 );
            END ;

			  SET @P_CODCID = @DSCIDADECOMERCIAL;
		      print (ISNULL(@DSCIDADECOMERCIAL,'M'));  
		      print (isnull(@P_CODCID,'M'));  
				print ('antes do insert par');
		    -- INSERE O CLIENTE NA TGFPAR
            INSERT INTO TGFPAR (
                                                      CODPARC, NOMEPARC, RAZAOSOCIAL, TIPPESSOA, CODEND,
                                                      NUMEND, COMPLEMENTO, CODBAI, CODCID, CEP,
                                                      TELEFONE, FAX, EMAIL,  DTCAD, CLIENTE, 
                                                      DTALTER, CODEMP, CGC_CPF, CODTIPPARC, IDENTINSCESTAD, 
                                                      CODVEND, DTNASC, AD_CLIENTEWMW, TEMIPI, CODPARCMATRIZ,
                                                      CLASSIFICMS, CSTIPIENT, CSTIPISAI, AD_ID, AD_INCMAILING, CODUSU
                                                      )
                                            VALUES   (
                                                      @P_CODPARC, @NMRAZAOSOCIAL, @NMRAZAOSOCIAL, @FLTIPOPESSOA, @P_CODEND,
                                                      @DSNUMEROLOGRADOUROCOMERCIAL, @DSCOMPLEMENTOCOMERCIAL, @P_CODBAI, @P_CODCID, @DSCEPCOMERCIAL,
                                                      @P_NUFONE, @P_TELEFONEALT, @DSEMAIL,  SYSDATETIME(), 'S', 
                                                      SYSDATETIME(), @CDEMPRESA, @NUCNPJ, '0' , @NUIERG, 
                                                      @CDREPRESENTANTE, @DTNASCIMENTO, @CDNOVOCLIENTE, 'N', @P_CODPARC,
                                                      'C', 49, 99, @COMOSOUBE, 'S', 426
                                                      );
                                                       
            -- BUSCA CODIGO DO CONTATO PARA INSERIR NA TGFCTT
            SELECT @P_CODCONTATO = ISNULL(MAX(CTT.CODCONTATO)+1,1) FROM TGFCTT CTT WHERE CTT.CODPARC = @P_CODPARC;
                                      
            -- INSERE O CLIENTE NA TGFCPL
            INSERT INTO TGFCTT (
                                                      CODPARC, CODCONTATO, NOMECONTATO,
                                                      TELEFONE, FAX, EMAIL, DTNASC, DTCAD, ATIVO
                                                      )
                                            VALUES   (
                                                      @P_CODPARC, @P_CODCONTATO, @NMRAZAOSOCIAL, 
                                                      @NUFONE, @TELEFONEALT, @DSEMAIL, @DTNASCIMENTO, SYSDATETIME(), 'S'
                                                      );
                                                             
            -- VERIFICA SE O PARCEIRO FOI INSERIDO COM SUCESSO
            SELECT @P_EXISTE_CLIENTE = ISNULL(1,0) FROM TGFPAR WHERE CGC_CPF = @NUCNPJ;
             
            IF (@P_EXISTE_CLIENTE = 1)
            BEGIN
                UPDATE TBLVWNOVOCLIENTE SET FLCONTROLEERP = 'E', DSMENSAGEMCONTROLEERP = 'NOVO CLIENTE INSERIDO COM SUCESSO', CDNOVOCLIENTERELACIONADO = @P_CODPARC
                WHERE
                CDEMPRESA = @CDEMPRESA  AND
                CDREPRESENTANTE = @CDREPRESENTANTE AND
                CDNOVOCLIENTE = @CDNOVOCLIENTE;
            END;
           
            -- FINALIZA O BEGIN TRANSACTION 
            COMMIT; 
            END TRY
              BEGIN CATCH
                 
                  SET @ERRORNUM = ERROR_NUMBER();
                  SET @ERRORMSG = ERROR_MESSAGE();
                     
                  ROLLBACK;
                       
                        UPDATE TBLVWNOVOCLIENTE SET FLCONTROLEERP = 'X', DSMENSAGEMCONTROLEERP = 'ERRO AO INSERIR NOVO CLIENTE.' + SUBSTRING(@ErrorMsg, 1, 200)
                        WHERE
                            CDEMPRESA = @CDEMPRESA  AND
                            CDREPRESENTANTE = @CDREPRESENTANTE AND
                            CDNOVOCLIENTE = @CDNOVOCLIENTE;
                        SET @RETORNO = 'ERRO';                       
                           
              END CATCH;
                 
        FETCH NEXT FROM CURSORCLIENTE INTO @NMRAZAOSOCIAL, @FLTIPOPESSOA, @CDREPRESENTANTE, @CDNOVOCLIENTE, @NUIERG, 
										   @NUCNPJ, @DSTIPOLOGRADOUROCOMERCIAL, @DSLOGRADOUROCOMERCIAL, @DSNUMEROLOGRADOUROCOMERCIAL, @DSCOMPLEMENTOCOMERCIAL, 
										   @DSBAIRROCOMERCIAL,  @DSCEPCOMERCIAL, @DSCIDADECOMERCIAL, @CDUFCOMERCIAL, @NUFONE, 
										   @TELEFONEALT, @DSEMAIL, @DTNASCIMENTO, @COMOSOUBE
      END;
    CLOSE CURSORCLIENTE
    DEALLOCATE CURSORCLIENTE
END