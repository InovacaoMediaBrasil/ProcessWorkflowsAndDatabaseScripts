USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_PRECKIT_CONFIRMAR_PRECO]    Script Date: 19/03/2018 17:38:38 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [sankhya].[STP_PRECKIT_CONFIRMAR_PRECO] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE
	@FIELD_CODPROD INT,
	@RESULTADO NUMERIC(15,2),
    @CODMATPRIMA INT,
    @NUTAB INT,
    @TOTALRESULTADO NUMERIC(15,4),
    @NUTABMAX INT,
    @I INT,
	@DATA DATETIME
BEGIN

	SET @I = 1 -- A variável "I" representa o registro corrente.
    WHILE @I <= @P_QTDLINHAS -- Este loop permite obter o valor de campos dos registros envolvidos na execução.
    BEGIN

		SET @DATA = GETDATE();
		/*
	     * Obtém o produto (KIT) atual
		 */
		SET @FIELD_CODPROD = SANKHYA.ACT_INT_FIELD(@P_IDSESSAO, @I, 'CODPROD');



		/*
		 * Se existir algum valor negativo no rateio, informa o usuário que
		 * foi encontrado um erro, para recalcular.
		*/

		IF EXISTS (SELECT RESULTADO from sankhya.AD_DETPRECKIT WITH(NOLOCK) WHERE CODPROD = @FIELD_CODPROD AND RESULTADO <=0)
			BEGIN

			RAISERROR(N'Foi encontrado um erro na precificação (Valor zerado ou negativo). Favor tentar novamente. ', 16, 1);
			RETURN

			END


		/*
		 * Obtem o número da tabela de preços vigente (NUTAB)
		 * onde o código de tabela de preços for o 0 (KIT só é vendido no WMW Vendas e na VA)!
		 */

		SELECT @NUTAB = MAX(NUTAB) 
		FROM TGFTAB WITH (NOLOCK)
		WHERE DTVIGOR = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),103)) 
		AND CODTAB = 0

		/*
		 * Se não existir nenhuma tabela de preços vigente, cria uma nova
		 */
			
		IF @NUTAB IS NULL
		BEGIN 

			/*
			 * Gera um novo NUTAB de acordo com a TGFNUM.
			 */
			
			SELECT @NUTAB = ULTCOD + 1 
			FROM TGFNUM WITH (NOLOCK)
			WHERE ARQUIVO='TGFTAB';

			/*
			 * Insere a nova TGFTAB com o NUTAB novo e data de vigencia atual.
			 */

			INSERT INTO TGFTAB (CODTAB, DTVIGOR, CODREG, DTALTER, PERCENTUAL, FORMULA, CODTABORIG, NUTAB, JAPE_ID)
			VALUES (0, CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),103)), NULL, CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),103)), NULL, NULL, NULL, @NUTAB, NULL);
			
			/*
			 * Atualiza a TGFNUM com o número utilizado
			 */

			UPDATE TGFNUM 
			SET ULTCOD = @NUTAB 
			WHERE ARQUIVO='TGFTAB'
		END

		/*
		 * Caso exista, utiliza ela
		 */

		ELSE
		BEGIN			
			
			/*
			 * Obtem o resultado de acordo com a precificação de KIT
			 */

			SELECT @TOTALRESULTADO = TOTALRESULT 
			FROM AD_PRECKIT WITH (NOLOCK)
			WHERE CODPROD = @FIELD_CODPROD
			
			/*
			 * Se não existir na TGFEXC faz INSERT, se não UPDATE
			 */
			IF NOT EXISTS(
					SELECT 1 
					FROM TGFEXC WITH (NOLOCK)
					WHERE CODPROD = @FIELD_CODPROD
					AND NUTAB = @NUTAB
				)					
				INSERT INTO TGFEXC (NUTAB, CODPROD, CODLOCAL, CONTROLE, VLRVENDA, TIPO, MODBASEICMS, PERCDESC, MARGLUCRO, PERCCOM, AD_CODUSU, AD_PRECIFICACAO)
				VALUES (@NUTAB, @FIELD_CODPROD, 0, '', @TOTALRESULTADO, 'V', 'O', NULL, NULL, NULL, @P_CODUSU, 'S')
			ELSE
				UPDATE TGFEXC 
				SET		VLRVENDA =			@TOTALRESULTADO, 
						AD_CODUSU =			@P_CODUSU,
						AD_PRECIFICACAO =	'S'
				WHERE CODPROD = @FIELD_CODPROD 
				AND NUTAB = @NUTAB
		END

		/*
		 * Obtém os componentes do KIT via cursor
		 */
		DECLARE CURSOR_PRECO CURSOR FOR
		SELECT CODPRODKIT, RESULTADO 
		FROM AD_DETPRECKIT WITH (NOLOCK)
		WHERE CODPROD =@FIELD_CODPROD;
	
		OPEN CURSOR_PRECO;
		FETCH NEXT FROM CURSOR_PRECO INTO @CODMATPRIMA,@RESULTADO;
		
		WHILE (@@FETCH_STATUS<>-1)
		BEGIN 

			/*
			 * Altera na TGFICP o preço do produto (componente)
			 */

			UPDATE TGFICP 
			SET AD_VLRVENDA = @RESULTADO 
			WHERE CODMATPRIMA = @CODMATPRIMA 
			AND CODPROD = @FIELD_CODPROD;

			/*
			 * Insere o histórico de precificação na tabela adicional
			 */

			INSERT INTO AD_TGFICPHIST (CODPROD, CODMATPRIMA, DTCADASTRO, NUTAB, VLRVENDA, CODUSU)
			VALUES (@FIELD_CODPROD, @CODMATPRIMA, @DATA, @NUTAB, @RESULTADO, @P_CODUSU);
			
			FETCH NEXT FROM CURSOR_PRECO INTO @CODMATPRIMA,@RESULTADO;
		END
		CLOSE CURSOR_PRECO;
		DEALLOCATE CURSOR_PRECO;
		
		
		/*
		 * Atualiza o peso e a data de alteração na TGFPRO
		 */

		UPDATE TGFPRO 
		SET PESOBRUTO = A.PESO, DTALTER = GETDATE()
		FROM AD_PRECKIT AS A WITH (NOLOCK)
		WHERE A.CODPROD = TGFPRO.CODPROD
		AND A.CODPROD = @FIELD_CODPROD		
			
		SET @I = @I + 1     
  END
END