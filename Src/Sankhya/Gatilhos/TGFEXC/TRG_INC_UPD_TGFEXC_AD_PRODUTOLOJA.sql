USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_UPD_TGFEXC_AD_PRODUTOLOJA]    Script Date: 14/09/2018 18:12:01 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	04/10/2013
	Description:	Atualiza AD_PRODUTOLOJA com VLRVENDA

	Author:			Guilherme Branco Stracini
	Change date:	15/05/2017
	Description:	CODCAT no INSERT na AD_PRODUTOLOJA e CURSOR para itens da INSERTED

	Author:			Guilherme Branco Stracini
	Change date:	19/03/2018
	Description:	Impede a precificação de KITs na tabela 0 diretamente pela tela Atualização de Preço de Venda 
					(validando o campo adicional AD_PRECIFICACAO que só é informado pela procedure de precificação de KIT)
					
	=============================================*/
ALTER TRIGGER [sankhya].[TRG_INC_UPD_TGFEXC_AD_PRODUTOLOJA] 
   ON  [sankhya].[TGFEXC] 
   AFTER INSERT, UPDATE
AS 
DECLARE
		@CODPROD INT,
		@VLRVENDA MONEY,
		@NUTAB INT,
		@NUTABOLD INT,
		@CODTAB INT,
		@CODLOJA INT,
		@CODVOL VARCHAR(2),
		@VLRVENDAOLD MONEY,
		@VLRVENDADE MONEY,
		@VLRVENDADELOG MONEY,
		@CODUSU INT,
		@CODCAT INT,
		@PRECIFICACAO CHAR(1)
BEGIN
	SET NOCOUNT ON;
	
	/*
	 * Obtém os produtos que foram cadastrados/atualizados na TGFEXC para o cursor
	 */

	DECLARE CURSOR_ITENS CURSOR FAST_FORWARD FOR
	SELECT I.CODPROD, I.VLRVENDA, I.NUTAB, I.AD_CODUSU, T.CODTAB, I.AD_PRECIFICACAO, P.CODVOL
	FROM INSERTED AS I
	INNER JOIN TGFTAB AS T WITH (NOLOCK)
	ON I.NUTAB = T.NUTAB
	INNER JOIN TGFPRO AS P WITH (NOLOCK)
	ON P.CODPROD = I.CODPROD;

	OPEN CURSOR_ITENS;

	FETCH NEXT FROM CURSOR_ITENS 
	INTO @CODPROD, @VLRVENDA, @NUTAB, @CODUSU, @CODTAB, @PRECIFICACAO, @CODVOL;

	WHILE @@FETCH_STATUS = 0
	BEGIN 
		
		IF @CODVOL = 'KT' 
		AND @CODTAB = 0
		AND @PRECIFICACAO = 'N'
		BEGIN
			RAISERROR('Não é possível precificar um KIT pela tela de Atualização de preço de venda!', 16, 1);
			RETURN;
		END

		/*
		 * Obtém os dados antigos do produto (valor e numero da tabela)
		 */

		SELECT @VLRVENDAOLD = D.VLRVENDA, @NUTABOLD = D.NUTAB
		FROM DELETED AS D
		WHERE D.NUTAB = @NUTAB
		AND D.CODPROD = @CODPROD;

		/*
		 * Se o nutab atual for diferente do nutab antigo (tabelas de preços diferentes)
		 * Obtém o preço de venda antigo e não da tabela DELETED
		 */

		IF @NUTAB != @NUTABOLD
			SELECT @VLRVENDAOLD = EXC.VLRVENDA
			FROM TGFEXC AS EXC WITH (NOLOCK)
			INNER JOIN sankhya.TGFTAB AS TAB WITH (NOLOCK)
			ON EXC.NUTAB = TAB.NUTAB
			WHERE EXC.CODPROD = @CODPROD 
			AND TAB.CODTAB = @CODTAB
			AND TAB.DTALTER IN (
				SELECT MAX(DTALTER) 
				FROM TGFTAB AS T2
				WHERE NUTAB IN (
					SELECT NUTAB 
					FROM TGFEXC
					WHERE CODPROD = @CODPROD
					AND NUTAB != @NUTAB
				)
			);		

		SET @VLRVENDADELOG = @VLRVENDAOLD;
	
		/*
		 * Se o valor antigo for menor do que o valor atual (aumento no preço)
		 * Marca o valor antigo como nulo.
		 */
		IF @VLRVENDAOLD <= @VLRVENDA
			SET @VLRVENDAOLD = NULL;
	
		/*
		 * Obtém todas as lojas que usam essa tabela de preços para o cursor.
		 */

		DECLARE CURSOR_LOJAS CURSOR FAST_FORWARD FOR
			SELECT CODLOJA 
			FROM AD_LOJA WITH (NOLOCK)
			WHERE CODTAB = @CODTAB;	
	
		OPEN CURSOR_LOJAS;

		FETCH NEXT FROM CURSOR_LOJAS INTO @CODLOJA
		WHILE @@FETCH_STATUS = 0
		BEGIN

			/*
			 * Obtém o valor atual/manual do "Preço de" da tabela multiloja/marketplace
			 */

			SELECT @VLRVENDADE = VLRVENDADE 
			FROM AD_PRODUTOLOJA
			WHERE CODPROD = @CODPROD 
			AND CODLOJA = @CODLOJA;

			/*
			 * Se o valor atual "Preço de" for maior que o valor de venda, a variavel do valor preço de estiver como nula, 
			 * seta o valor de preço de como o valor existente na multiloja/marketplace
			 */
			IF @VLRVENDADE > @VLRVENDA AND @VLRVENDAOLD IS NULL
				SET @VLRVENDAOLD = @VLRVENDADE;

			/*
			 * Caso seja uma precificação nova, o item ainda não existe na tabela AD_PRODUTOLOJA, e essa tabela precisa do campo
			 * CODCAT preenchido, coloca 0 para WMWVendas e 106 (Integração) para lojas VTEX
			 */
			SET @CODCAT = 0;
			IF @CODLOJA > 0
				SET @CODCAT = 106;
									
			/*
			 * Verifica se já existe uma entrada na produto loja para este produto/loja, caso exista faz o update dos valores
			 * Caso não exista faz o insert
			 */
			IF EXISTS(SELECT 1 FROM AD_PRODUTOLOJA WITH (NOLOCK) WHERE CODPROD = @CODPROD AND CODLOJA = @CODLOJA)
				UPDATE AD_PRODUTOLOJA 
				SET VLRVENDA = @VLRVENDA, VLRVENDADE = @VLRVENDAOLD, DTALTER = GETDATE(), CODUSU = @CODUSU
				WHERE CODPROD = @CODPROD 
				AND CODLOJA = @CODLOJA;
			ELSE
				INSERT INTO AD_PRODUTOLOJA (ATIVO, CODLOJA, CODPROD, PESTTLOJA, VLRVENDA, DTALTER, CODUSU, CODCAT) 
				VALUES('N', @CODLOJA, @CODPROD, 0, @VLRVENDA, GETDATE(), @CODUSU, @CODCAT);
				
			/*
			 * Faz o insert na tabela de log de alterações da VTEX se o código da loja for maior que 0 (0 - WMW Vendas | 1..N VTEX)
			 */
			IF @CODLOJA > 0
				INSERT INTO AD_LOGALTERACOESVTEX (CODPROD, DTALTER, OCORRENCIA)
				SELECT @CODPROD, GETDATE(), 'Preço alterado de R$' + CAST(ISNULL(@VLRVENDADELOG, -1) AS VARCHAR) + ' para R$' + CAST(@VLRVENDA AS VARCHAR) + ' (Preço de: R$ ' + CAST(ISNULL(@VLRVENDAOLD, 0) AS VARCHAR) + ') na loja ' + NOMELOJA
				FROM AD_LOJA WITH (NOLOCK)
				WHERE CODLOJA = @CODLOJA

			FETCH NEXT FROM CURSOR_LOJAS INTO @CODLOJA
		END 
		CLOSE CURSOR_LOJAS;
		DEALLOCATE CURSOR_LOJAS;
		
		FETCH NEXT FROM CURSOR_ITENS 
		INTO @CODPROD, @VLRVENDA, @NUTAB, @CODUSU, @CODTAB, @PRECIFICACAO, @CODVOL;
	END

	CLOSE CURSOR_ITENS;
	DEALLOCATE CURSOR_ITENS;
END
