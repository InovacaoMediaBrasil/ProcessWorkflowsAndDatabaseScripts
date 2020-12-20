USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_IMP_ASSINATURAS]    Script Date: 11/09/2018 17:07:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Batch submitted through debugger: SQLQuery1.sql|7|0|C:\Users\Administrator\AppData\Local\Temp\4\~vs926A.sql


ALTER PROCEDURE [sankhya].[STP_IMP_ASSINATURAS]
(@RETORNO            VARCHAR(20) OUTPUT) 
AS
BEGIN
     
SET LANGUAGE BRAZILIAN;
     
    -- VARIAVEIS
	DECLARE @P_NUMASSINATURA                      INT;
    DECLARE @P_EXISTE_CLIENTE                     INT;
    DECLARE @P_EXISTE_CLIENTE_NOME                INT;
    DECLARE @P_CODIGO                             INT;
    DECLARE @P_CODPARC                            INT;
    DECLARE @P_CODCONTATO                         INT;
    DECLARE @P_AUTO                               CHAR(100);
    DECLARE @P_CODCID                             INT;
    DECLARE @P_CODBAI                             INT;
    DECLARE @P_CODEND                             INT;
    DECLARE @P_CODUF                              CHAR(25);
    DECLARE @P_NUFONE							  VARCHAR(100);
    DECLARE @P_TELEFONEALT 						  VARCHAR(100);
	DECLARE @P_ULTIMO_CODIGO                      DECIMAL(16,2);
	DECLARE @TENTATIVA							  INT = 0; 
    DECLARE @P_SYSDATE                            VARCHAR(100);
	DECLARE @PENDENTE						      CHAR(1);

    -- VARIAVEIS DO CURSOR PARC
    DECLARE @NOME                                   VARCHAR(200);
    DECLARE @TELEFONE                               VARCHAR(200);
    DECLARE @EMAIL				    			    VARCHAR(100);
    DECLARE @CPF                                    VARCHAR(100);
    DECLARE @ENDERECO                               VARCHAR(100);
    DECLARE @NUMEND                                 VARCHAR(200);    
    DECLARE @COMPLEMENTO                            VARCHAR(200);
    DECLARE @BAIRRO                                 VARCHAR(200);
    DECLARE @CEP                                    VARCHAR(200);
    DECLARE @CIDADE                                 VARCHAR(100);
    DECLARE @UF                                     VARCHAR(200);



        -- CURSOR ITEMPEDIDO
    DECLARE @CDPRODUTO                                          VARCHAR(20);
    DECLARE @VLRPEDIDO                                          DECIMAL(16,7);
    DECLARE @QTDNEG                                             INT;
    DECLARE @CDUNIDADE                                          VARCHAR(20);
    DECLARE @VLRUNIT                                            DECIMAL(16,7);

		--CURSOR CAB
    DECLARE @P_NUNOTA							  INT;
    DECLARE @CDTIPOPEDIDO						  INT;
	DECLARE @P_DATA								  DATETIME;
	DECLARE @P_DTHORA							  DATETIME;
	DECLARE @HRMOV								  VARCHAR;
	DECLARE @P_DHALTER_TOP						  DATETIME;
	DECLARE @P_DHALTER_TPV						  DATETIME;
	DECLARE @CODTIPOPER							  INT;
	DECLARE @CODTIPVENDA						  INT;
	DECLARE @NUSEQPEDIDO						  INT; 
	DECLARE @OBSERVACAO							  VARCHAR(200);
	DECLARE @P_VLTOTALITEMPEDIDO				  DECIMAL(16,7);
	DECLARE @NUTAB								  INT;

    -- VARIAVEIS PARA TRATAMENTO DE ERROS
    DECLARE @ERRORNUM                             INT;
    DECLARE @ERRORSEVERITY                        INT;
    DECLARE @ERRORMSG                             VARCHAR(400);
    DECLARE @ERRORMESSAGE                         VARCHAR(400);     
    -- CURSOR CLIENTE
    --VERIFICADOR
    DECLARE @VERIFICADOR                        TABLE (ID INT NOT NULL identity(1,1) , NUMASSINATURA INT);
    DECLARE @LARGURA                            INT;
    
    
    SET @RETORNO = 'OK'
  --  SELECT  @LARGURA =  COUNT(*) FROM sankhya.AD_ASSINATURAS WHERE PENDENTE = 'S' OR PENDENTE IS NULL  
  --INSERT INTO #VERIFICADOR (NUMASSINATURA) SELECT NUMASSINATURA FROM sankhya.AD_ASSINATURAS WHERE PENDENTE = 'S' OR PENDENTE = 'NULL'
  --SELECT * FROM @VERIFICADOR
  --      WHILE @LARGURA > 0
		--BEGIN
		--PRINT @LARGURA 
  -- SELECT @P_NUMASSINATURA = NUMASSINATURA FROM @VERIFICADOR WHERE ID = @LARGURA 
 
 SELECT  @LARGURA =  COUNT(*) FROM sankhya.AD_ASSINATURAS WHERE PENDENTE = 'S' OR PENDENTE IS NULL 
    DECLARE CURSORCLIENTE CURSOR LOCAL FOR
             SELECT CLI.VLRNOTA, CLI.OBSERVACAO, CLI.QTDNEG, CLI.VLRUNIT, CLI.NUMASSINATURA, SUBSTRING(UPPER(CLI.NOMEPARCEIRO),0,40), REPLACE(REPLACE(REPLACE(CLI.CPF,'.',''),'/',''),'-',''), SUBSTRING(UPPER(CLI.ENDERECO),0,60), CLI.NUMEND, SUBSTRING(UPPER(CLI.COMPLEMENTO),0,30), 
					SUBSTRING(UPPER(CLI.BAIRRO),0,20), CLI.CEP,  SUBSTRING(UPPER(CLI.CIDADE),0,20),CLI.UF, REPLACE(REPLACE(CLI.TELEFONE,'(',''),')',''), CLI.EMAIL
             FROM sankhya.AD_ASSINATURAS CLI
             WHERE PENDENTE = 'S' OR PENDENTE IS NULL
    OPEN CURSORCLIENTE



  -- WHILE @@FETCH_STATUS = 0
  WHILE @LARGURA > 0
   BEGIN 
    PRINT N'NÚMERO DE ASSINATURAS PARA IMPORTAÇÃO: ' + RTRIM(CAST(@LARGURA AS VARCHAR(20)));
   		FETCH NEXT FROM CURSORCLIENTE INTO @VLRPEDIDO, @OBSERVACAO, @QTDNEG, @VLRUNIT, @P_NUMASSINATURA, @NOME, @CPF, @ENDERECO, @NUMEND, @COMPLEMENTO, 
											   @BAIRRO,  @CEP, @CIDADE, @UF, @TELEFONE, @EMAIL
											   PRINT ' PROCESSANDO NUMERO DE ASSINATURA: '
   PRINT @P_NUMASSINATURA 
   PRINT @CPF
   IF @P_NUMASSINATURA IS NULL
        RETURN
    		IF EXISTS (SELECT 1 FROM sankhya.TGFCAB WHERE AD_PEDIDOWMW = @P_NUMASSINATURA) 
		BEGIN
        UPDATE sankhya.AD_ASSINATURAS SET PENDENTE = 'N' WHERE NUMASSINATURA = @P_NUMASSINATURA
        SET @PENDENTE = 'N'
        END
		ELSE 
        BEGIN
        UPDATE sankhya.AD_ASSINATURAS SET PENDENTE = 'S' WHERE NUMASSINATURA = @P_NUMASSINATURA
		SET @PENDENTE = 'S'
        END
		WHILE @PENDENTE = 'N'
		BEGIN
		PRINT 'ASSINATURA JÁ EXISTENTE NO SANKHYA!'
			IF @LARGURA <= 0
			RETURN 
				SET @LARGURA = @LARGURA - 1
   		FETCH NEXT FROM CURSORCLIENTE INTO @VLRPEDIDO, @OBSERVACAO, @QTDNEG, @VLRUNIT, @P_NUMASSINATURA, @NOME, @CPF, @ENDERECO, @NUMEND, @COMPLEMENTO, 
											   @BAIRRO,  @CEP, @CIDADE, @UF, @TELEFONE, @EMAIL
	
    	IF EXISTS (SELECT 1 FROM sankhya.TGFCAB WHERE AD_PEDIDOWMW = @P_NUMASSINATURA) 
			BEGIN
			UPDATE sankhya.AD_ASSINATURAS SET PENDENTE = 'N' WHERE NUMASSINATURA = @P_NUMASSINATURA
			SET @PENDENTE = 'N'
			END
		ELSE 
			BEGIN
			UPDATE sankhya.AD_ASSINATURAS SET PENDENTE = 'S' WHERE NUMASSINATURA = @P_NUMASSINATURA
			SET @PENDENTE = 'S'
			END
			

        	IF EXISTS (SELECT 1 FROM sankhya.TGFCAB WHERE CODPARC = @P_CODPARC AND CODTIPOPER = 574)
			BEGIN
			PRINT 'ASSINATURA COM ESSE PARCEIRO JÁ EXISTENTE! ABORTANDO'
			 UPDATE sankhya.AD_ASSINATURAS SET PENDENTE = 'N' WHERE NUMASSINATURA = @P_NUMASSINATURA
			 SET @PENDENTE = 'N'
			 CLOSE CURSORCLIENTE
				DEALLOCATE CURSORCLIENTE
			RETURN
			END


		END
    

   IF @LARGURA = 0
	 BEGIN 
	 PRINT 'NÃO EXISTEM ASSINATURAS PENDENTES PARA IMPORTAÇÃO!'
	 RETURN
	 END

	                PRINT 'GO!'
       -- VERIFICA SE O PARCEIRO FOI INSERIDO COM SUCESSO

       SELECT @P_EXISTE_CLIENTE = ISNULL(MAX(1),0) FROM TGFPAR WHERE CGC_CPF = @CPF;
	   SELECT @P_EXISTE_CLIENTE_NOME = ISNULL(MAX(1),0) FROM TGFPAR WHERE NOMEPARC = @NOME;
	   PRINT @P_EXISTE_CLIENTE
	   		IF (@P_EXISTE_CLIENTE = 1) OR (@P_EXISTE_CLIENTE_NOME = 1)
            BEGIN
                 SELECT @P_CODPARC = CODPARC FROM TGFPAR WHERE CGC_CPF = @CPF;
				 IF EXISTS (SELECT CODPARC FROM TGFPAR WHERE CGC_CPF = @CPF)
				 PRINT 'EXISTE PARCEIRO PARA CPF'
				 ELSE
				 SELECT @P_CODPARC = CODPARC FROM TGFPAR WHERE NOMEPARC = @NOME;
				PRINT 'PARCEIRO DE ASSINATURA EXISTENTE!'

            END 
ELSE IF (@P_EXISTE_CLIENTE = 0)

    BEGIN
	PRINT 'NÃO EXISTE PARCEIRO! CRIANDO...' 
        BEGIN TRANSACTION;
             
        BEGIN TRY

            SELECT @P_CODCID = ISNULL(MAX(CODCID),0) FROM TSICEP WHERE CEP = @CEP;
		--	SELECT @P_CODCID = ISNULL(MAX(CODCID),0) FROM TSICEP WHERE CODCID = @CIDADE;
            SELECT @P_CODUF  = ISNULL(CODUF,0)       FROM TSIUFS WHERE UF = @UF;
			PRINT (ISNULL(@CIDADE, 'NULO'))  
             
        -- CADASTRO DE CIDADE
        IF (@P_CODCID = 0)
        BEGIN
        -- TENTA ACHAR A CIDADE PELO CODIGO
        SELECT @P_CODCID = CODCID FROM SANKHYA_PRODUCAO.SANKHYA.TSICID WHERE NOMECID = UPPER(@CIDADE) AND UF = @P_CODUF;  
--     SET @P_CODCID = @CIDADE;
        END;
        IF (@P_CODCID= 0 OR @P_CODCID = NULL)
        BEGIN
        -- BUSCA TIPO DE NUMERACAO
            SELECT @P_AUTO = AUTOMATICO FROM TGFNUM WHERE ARQUIVO = 'TSICID';
            SELECT @P_CODIGO = ULTCOD   FROM TGFNUM WHERE ARQUIVO = 'TSICID';
        
            -- NUMERACAO AUTOMATICA
            IF (@P_AUTO = 'S')
            BEGIN
						UPDATE TGFNUM SET ULTCOD = ULTCOD + 1 WHERE ARQUIVO = 'TSICID';
						SET @P_CODCID = @P_CODIGO + 1;
						-- INSERE CIDADE NA TABELA DA SANKHYA
						INSERT INTO TSICID (CODCID, UF, NOMECID, DTALTER)
														     VALUES (@P_CODCID, @P_CODUF, @CIDADE, SYSDATETIME());
					END;
            ELSE
            BEGIN
              -- NUMERACAO MANUAL. VAI BUSCAR O MAIOR CODIGO DE CIDADE NA TABELA
              SELECT @P_CODIGO = MAX(CODCID) FROM TSICID;
              SET @P_CODCID = @P_CODIGO + 1;
              -- INSERE CIDADE NA TABELA DA SANKHYA
              INSERT INTO TSICID (CODCID, UF, NOMECID, DTALTER)
                                               VALUES (@P_CODCID, @P_CODUF, @CIDADE, SYSDATETIME());
            END;
   --       SELECT @P_CODCID = CODCID FROM TSICID WHERE CODCID = UPPER(@CIDADE) AND UF = @P_CODUF;   
          END
		  		   PRINT 'CADASTRO DE CIDADE CONCLUIDO!'
		  -- CADASTRO DE BAIRRO
          IF (@BAIRRO IS NOT NULL)
			SELECT @P_CODBAI = ISNULL(MAX(CODBAI),0) FROM TSIBAI WHERE UPPER(NOMEBAI) = UPPER(@BAIRRO);
		       
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
															VALUES (@P_CODBAI, @BAIRRO, SYSDATETIME());
                      END
                      ELSE
						BEGIN
                      -- NUMERACAO MANUAL. VAI BUSCAR O MAIOR CODIGO DE BAIRRO NA TABELA
                          SELECT @P_CODIGO = MAX(CODBAI) FROM TSIBAI;
                          SET @P_CODBAI = @P_CODIGO + 1;
                          -- INSERI BAIRRO NA TABELA DA SANKHYA
                          INSERT INTO TSIBAI (CODBAI, NOMEBAI, DTALTER)
														      VALUES (@P_CODBAI, @BAIRRO, SYSDATETIME());
						END  
                   END
		
		   -- CADASTRO DE LOGRADOURO   
           IF (@CEP IS NOT NULL)
              SELECT @P_CODEND = ISNULL(MAX(CODEND),0) FROM TSIEND WHERE UPPER(NOMEEND) = UPPER(@ENDERECO);
            
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
									  INSERT INTO TSIEND (CODEND, NOMEEND, DTALTER)
																		  VALUES  (@P_CODEND, @ENDERECO, SYSDATETIME());
                  END
                  ELSE
                  BEGIN
                  -- NUMERACAO MANUAL. VAI BUSCAR O MAIOR CODIGO DE ENDERECO NA TABELA
                      SELECT @P_CODEND = MAX(CODEND)+ 1 FROM TSIEND;
                      INSERT INTO TSIEND (CODEND, NOMEEND, DTALTER)
                                                      VALUES  (@P_CODEND, @ENDERECO, SYSDATETIME());
                  END

				  END
               
            -- INSERE LOGRADOURO NA VARIAVEL
            SET @NUMEND = ISNULL(@NUMEND,'0');
            IF @NUMEND = '0'
            BEGIN
               SET @NUMEND = 'S/N';
            END
            ELSE
            BEGIN
               SET @NUMEND = @NUMEND;
            END
               
            -- BUSCA TIPO DE NUMERACAO
               SELECT @P_AUTO = AUTOMATICO FROM TGFNUM WHERE ARQUIVO = 'TGFPAR';
               SELECT @P_CODIGO = ULTCOD   FROM TGFNUM WHERE ARQUIVO = 'TGFPAR';
                  
            -- NUMERACAO AUTOMATICA
            IF (@P_AUTO = 'S')
            BEGIN
                UPDATE TGFNUM SET ULTCOD = ULTCOD + 1 WHERE ARQUIVO = 'TGFPAR';
                SET @P_CODPARC = @P_CODIGO + 1;
            END
            ELSE
            BEGIN
                -- NUMERACAO MANUAL. VAI BUSCAR O MAIOR CODIGO DE PARCEIRO NA TABELA
                SELECT @P_CODIGO = MAX(CODPARC) FROM TGFPAR;
                SET @P_CODPARC = @P_CODIGO + 1;
            END
            
            -- Trata campo TELEFONE
            IF (LEN(@TELEFONE) = 11) 
            BEGIN
				SET @P_NUFONE = SUBSTRING(@TELEFONE, 1, 2) + '  ' + SUBSTRING(@TELEFONE, 3, 5) + '' + SUBSTRING(@TELEFONE, 8,4 );
            END
            ELSE 
            BEGIN
				SET @P_NUFONE = SUBSTRING(@TELEFONE, 1, 2) + '  ' + SUBSTRING(@TELEFONE, 3, 4) + '' + SUBSTRING(@TELEFONE, 7,4 );
            END


			                    PRINT 'INSERINDO DADOS NA TGFPAR'    
								             
            INSERT INTO TGFPAR (
                                                      CODPARC, NOMEPARC, RAZAOSOCIAL, TIPPESSOA, CODEND,
                                                      NUMEND, COMPLEMENTO, CODBAI, CODCID, CEP,
                                                      TELEFONE, EMAIL,  DTCAD, CLIENTE, 
                                                      DTALTER, CGC_CPF, CODTIPPARC, 
                                                      TEMIPI, CODPARCMATRIZ,
                                                      CLASSIFICMS, CSTIPIENT, CSTIPISAI, AD_INCMAILING, CODUSU
                                                      )
                                            VALUES   (
                                                      @P_CODPARC, @NOME, @NOME, 'F', @P_CODEND,
                                                      @NUMEND, @COMPLEMENTO, @P_CODBAI, @P_CODCID, @CEP,
                                                      @P_NUFONE, @EMAIL,  SYSDATETIME(), 'S', 
                                                      SYSDATETIME(), @CPF, '0' , 'N', @P_CODPARC,
                                                      'C', 49, 99, 'S', 67
                                                      );


               -- UPDATE sankhya.AD_ASSINATURAS SET PENDENTE = 'N' WHERE NUMASSINATURA = @P_NUMASSINATURA;
                 

		    -- INSERE O CLIENTE NA TGFPAR

                                                             
            -- BUSCA CODIGO DO CONTATO PARA INSERIR NA TGFCTT
            -- INSERE O CLIENTE NA TGFCPL

													  PRINT 'NOVO PARCEIRO DE ASSINATURA INSERIDO COM SUCESSO!'
              
            
 
            PRINT @P_CODPARC
	

      -- FINALIZA O BEGIN TRANSACTION 
        COMMIT;
		
		
		
            END TRY
              BEGIN CATCH
                 
                  SET @ERRORNUM = ERROR_NUMBER();
                  SET @ERRORMSG = ERROR_MESSAGE();
                     
                     PRINT @ERRORNUM
                     PRINT @ERRORMSG
                  ROLLBACK;
                        SET @RETORNO = 'ERRO';                       
                           
              END CATCH;
                 END

  PRINT ''
 
		-- SET INFO
		SET @CODTIPOPER = 574
		SET @CODTIPVENDA = 80
        SET @CDPRODUTO = 19192
		--VERIFICA SE PEDIDO JA FOI PROCESSADO

			
				-- BUSCA NUMERACAO TGFCAB
				INICIO:    
				SELECT 
					@P_ULTIMO_CODIGO = ULTCOD 
				FROM TGFNUM 
				WHERE 
					ARQUIVO = 'TGFCAB';
				
				SET @P_NUNOTA = @P_ULTIMO_CODIGO + 1;
              
				UPDATE TGFNUM 
					SET ULTCOD = @P_NUNOTA 
				WHERE 
					ARQUIVO = 'TGFCAB' 
				AND ULTCOD = @P_ULTIMO_CODIGO;
               
				IF @@ROWCOUNT = 0 AND @TENTATIVA < 10 
					BEGIN 
						SET @TENTATIVA = @TENTATIVA + 1;  
						GOTO 
						INICIO 
					END


				-- DATA DA INSERCAO
				SELECT @P_DATA = CAST(FLOOR(CAST(GETDATE() AS FLOAT)) AS DATETIME);
                 
				-- DATA/HORA DA INSERCAO
				SELECT @P_DTHORA = CAST(CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 120), 120) AS DATETIME);
                                    
				-- HORARIO DA MOVIMENTACAO
				SELECT @HRMOV = REPLACE(CONVERT(VARCHAR, GETDATE(), 108),':','');
                

                
                                                       
				-- BUSCA MAX(DHALTER) DA TOP
				SELECT 
					@P_DHALTER_TOP = MAX(DHALTER) 
				FROM TGFTOP WITH(NOLOCK)
				WHERE 
					CODTIPOPER = @CODTIPOPER;
				--BUSCA MAX(DHALTER) DA TOP E TPV
				SELECT 
					@P_DHALTER_TPV = MAX(DHALTER) 
				FROM TGFTPV WITH(NOLOCK)
				WHERE 
					CODTIPVENDA = @CODTIPVENDA;
           

		--WHILE @@FETCH_STATUS = 0

		           PRINT @QTDNEG
                                 IF @QTDNEG IS NULL
                                 BEGIN
                                                        PRINT 'QTDNEG NEGATIVO!'
                                                        RETURN
                                                        
                                                        END
			BEGIN
				BEGIN TRY


  
			BEGIN TRANSACTION;
			-- INCLUI CABEÇALHO DO PEDIDO

                    
                                   INSERT INTO sankhya.TGFCAB (
                            	/*1*/ NUNOTA, CODEMP, NUMNOTA, SERIENOTA, CODCENCUS,
								/*2*/ DTNEG, DTENTSAI, DTMOV, HRMOV, CODEMPNEGOC,
								/*3*/ CODPARC, CODTIPOPER, DHTIPOPER, CODTIPVENDA, DHTIPVENDA,
								/*4*/ CODVEND, DTALTER, CODUSU, CODUSUINC, TIPFRETE, CIF_FOB,
								/*5*/ CODNAT, CODPROJ, ISSRETIDO, IRFRETIDO, OBSERVACAO,
								/*6*/ AD_PEDIDOWMW, CODPARCDEST, VLRNOTA, DTPREVENT, AD_STATUSPGTO,  
								/*7*/ CODPARCTRANSP, AD_PEDORIGINAL, TIPMOV
								)
						VALUES (
								/*1*/ @P_NUNOTA, 4, 0, 1, 90300,
								/*2*/ CAST(GETDATE() AS DATE), CAST(GETDATE() AS DATE), CAST(GETDATE() AS DATE), (DATEPART(HOUR,GETDATE())*100 + DATEPART(MINUTE,GETDATE())), 4,
								/*3*/ @P_CODPARC, @CODTIPOPER, @P_DHALTER_TOP, 80, @P_DHALTER_TPV,
								/*4*/ 371, GETDATE(), 448, 448, 'S', 'F',
								/*5*/ 110400, 0, 'N', 'S', @OBSERVACAO,
								/*6*/ @P_NUMASSINATURA, @P_CODPARC, @VLRPEDIDO, CAST(GETDATE() AS DATE), 'E',    
								/*7*/ 0, @P_NUNOTA, 'V'
								);
		
        									
				--SET @NUSEQPEDIDO = ISNULL((SELECT MAX(SEQUENCIA) FROM TGFITE WITH(NOLOCK) WHERE NUNOTA = @P_NUNOTA),0)+1;
				SET @NUTAB = (select MAX(NUTAB) from SANKHYA_PRODUCAO.sankhya.TGFEXC WITH(NOLOCK) WHERE CODPROD = @CDPRODUTO)						
                                                    
				--BUSCA VALORES DO ITEM
				--SET @P_QTDITEM = @QTITEMFISICO;
				--SET @P_VLITEMPEDIDO = @VLITEMPEDIDO;
				--SET @VLRUNIT = @VLBASEITEMPEDIDO;
                                              
		    PRINT 'PEDIDO CRIADO COM SUCESSO'                                   
			                                 
				-- ENCONTRA O VALOR TOTAL DO ITEM 
				SET @P_VLTOTALITEMPEDIDO = @VLRUNIT * @QTDNEG;                   							
				-- INCLUI ITENS NO PEDIDO
				INSERT INTO sankhya.TGFITE (
									/*1*/ NUTAB, NUNOTA, SEQUENCIA, CODEMP, CODPROD, 
									/*2*/ CODLOCALORIG, CONTROLE, USOPROD, QTDNEG, 
									/*3*/ QTDENTREGUE, QTDCONFERIDA, VLRUNIT, VLRTOT, 
									/*4*/ BASEIPI, VLRIPI, BASEICMS, VLRICMS, VLRDESC, 
									/*5*/ BASESUBSTIT, VLRSUBST, ALIQICMS, ALIQIPI, PENDENTE, 
									/*6*/ CODVOL, CODTRIB, ATUALESTOQUE, OBSERVACAO, RESERVA, 
									/*7*/ STATUSNOTA, BASESTANT, CODVEND, CODEXEC, FATURAR,
									/*8*/ VLRREPRED, VLRDESCBONIF, PERCDESC, M3, ALIQICMSRED, 
									/*9*/ CODPARCEXEC, CUSTO, BASESUBSTSEMRED, CODUSU, DTALTER, 
									/*10*/SOLCOMPRA, ATUALESTTERC, TERCEIROS, PRECOBASE, VLRACRESCDESC, 
									/*11*/VLRRETENCAO, CSTIPI, QTDWMS, BASESTUFDEST, VLRICMSUFDEST, 
									/*12*/VLRPROMO, QTDPECA, NUPROMOCAO, PERCDESCTGFDES, CODCFO
									)
							VALUES (
									/*1*/ @NUTAB, @P_NUNOTA, 1, 4, 19192, 
									/*2*/ 0, ' ', 'R', @QTDNEG, 
									/*3*/ 0, 0, @VLRUNIT, @P_VLTOTALITEMPEDIDO , 
									/*4*/ 0, 0, 0, 0, 0,
									/*5*/ 0, 0, 0, 0, 'S',
									/*6*/ 'UN', 41, 0, NULL, 'N', 
									/*7*/ 'A', 0, 0, 0, 'S',
									/*8*/ 0, 0, 0, 0, 0, 
									/*9*/ 0, 0, 0, 426, GETDATE(), 
									/*10*/'N', 'N', 'N', 0, 0, 
									/*11*/0, 0, 0, 0, 0, 
									/*12*/0, 0, 0, 0, 5922
						);  

            PRINT @P_NUNOTA
                                            PRINT 'ITENS INSERIDOS COM SUCESSO!' 
		   -- FINALIZA O BEGIN TRANSACTION 
           	UPDATE sankhya.AD_ASSINATURAS SET PENDENTE = 'N' WHERE NUMASSINATURA = @P_NUMASSINATURA
            COMMIT

            END TRY
              BEGIN CATCH
                 
                  SET @ERRORNUM = ERROR_NUMBER();
                  SET @ERRORMSG = ERROR_MESSAGE();
                     
                     PRINT @ERRORNUM
                     PRINT @ERRORMSG
                  ROLLBACK;
                        SET @RETORNO = 'ERRO';                       
                           
              END CATCH;
                 
 SET @LARGURA = @LARGURA - 1
 PRINT 'NÚMERO DE ASSINATURAS PENDENTE PARA IMPORTAÇÃO: ' + RTRIM(CAST(@LARGURA AS VARCHAR(20)));
END
END
CLOSE CURSORCLIENTE
DEALLOCATE CURSORCLIENTE

END


				--	--ARMAZENA VALOR PENDENTE EM VARIAVEL PARA CHECAR IMPORTAÇÃO DE ASSINATURAS
				--	SELECT @PENDENTE = PENDENTE FROM AD_ASSINATURAS WHERE NUMASSINATURA = @P_NUMASSINATURA        
				--				-- ATUALIZA PENDENTE DO ITEM DO PEDIDO
				--IF @PENDENTE = 'S' 
    --                PRINT 'PEDIDO NÃO IMPORTADO COM SUCESSO, VERIFIQUE OS VALORES DO ITEM DA ASSINATURA E DO CADASTRO DO PRODUTO, E TENTE NOVAMENTE'
                        
                        --ELSE IF @PENDENTE = 'N'			