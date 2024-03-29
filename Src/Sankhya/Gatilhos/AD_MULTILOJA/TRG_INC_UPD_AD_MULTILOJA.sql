USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_UPD_AD_MULTILOJA]    Script Date: 28/03/2017 18:37:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2014-04-08
	Description:	Atualiza campo "ESTOQUE" na tela MULTILOJA quando ocorrer alteraçãoo de estoque (campo ALTESTOQUE for alterado) e faz a divisão de porcentagem por lojas.

	Author:			Rodrigo Lacalendola
	Change date:	2016-10-13
	Description:	Obtém os decimais da quantidade do item para arredondar segundo as informações do produto

	Author:			Guilherme Branco Stracini
	Change date:	2016-12-02
	Description:	Verifica se houve alteração da flag de estoque para S ou se mudou a loja prioritária

	Author:			Guilherme Branco Stracini	
	Change date:	2017-03-28
	Description:	Documentação e melhorado fluxo da trigger (diminuido select, invertido ifs)
	 ============================================= */
ALTER TRIGGER [sankhya].[TRG_INC_UPD_AD_MULTILOJA] 
   ON  [sankhya].[AD_MULTILOJA]
   AFTER INSERT,UPDATE
AS 
DECLARE
@CODPROD INT,
@CODLOJA INT,
@ATIVAS INT,
@PORCENTAGEM FLOAT,
@SALDO FLOAT,
@PORLOJA FLOAT,
@CODLOJATOTALIDADE INT,
@CODLOJAPRIO INT,
@ALTESTOQUE CHAR(1),
@CODLOJAPRIOANTIGA INT
BEGIN
	SET NOCOUNT ON;	
	
	/*
	 * Se não atualizou o campo ALTESTOQUE e nem o campo CODLOJAPRIO encerra gatilho
	 */
	IF NOT UPDATE(ALTESTOQUE) AND NOT UPDATE(CODLOJAPRIO)
		RETURN;

	/*
	 * Se o novo valor do campo ALTESTOQUE não for S ou o código da loja prioritária não for diferente, encerra gatilho
	 */
	IF NOT EXISTS(
		SELECT 1 
		FROM INSERTED AS I
		INNER JOIN DELETED AS D 
		ON I.CODPROD = D.CODPROD
		WHERE I.ALTESTOQUE = 'S' 
		OR I.CODLOJAPRIO != D.CODLOJAPRIO)
		RETURN;
	
	/*
	 * Obtém as informações do produto
	 */
	SELECT	@CODPROD =		I.CODPROD, 
			@SALDO =		ROUND(sankhya.FN_ESTOQUE_INOVACAO(I.CODPROD), P.DECQTD), 
			@CODLOJAPRIO =	I.CODLOJAPRIO 
	FROM sankhya.TGFPRO AS P WITH (NOLOCK)
	INNER JOIN INSERTED AS I
	ON I.CODPROD = P.CODPROD

	/*
	 * Atualiza a quantidade de estoque para o produto na própria tela
	 */
	UPDATE AD_MULTILOJA 
	SET ESTOQUE = @SALDO 
	WHERE CODPROD = @CODPROD;
		
	/*
	 * Se o nível de aninhamento de triggers for maior que 5 encerra a trigger
	 */
	IF (SELECT TRIGGER_NESTLEVEL()) > 5
		RETURN; 
	
	/*
	 * Obtém a quantidade de lojas que o produto está ativo
	 */	
	SELECT @ATIVAS = COUNT(*) 
	FROM AD_PRODUTOLOJA WITH (NOLOCK)
	WHERE CODPROD = @CODPROD 
	AND ATIVO = 'S';
			
	/*
	 * Inicializa as variaveis
	 */
	SET @PORCENTAGEM = 100;
	SET @PORLOJA = @SALDO;

	/*
	 * Se existir pelo menos uma loja ativa, faz a divisão de porcentagem e por loja
	 */
	IF @ATIVAS > 0
	BEGIN
		SET @PORCENTAGEM = ROUND(100 / @ATIVAS,2);
		SET @PORLOJA = ROUND(@SALDO / @ATIVAS,2);
	END

	/*
	 * Se a quantidade disponível por loja ativa for igual ou maior que 1 ou o saldo for 0
	 */
	IF @PORLOJA >= 1 
	OR @SALDO = 0
	BEGIN

		/*
		 * Atualiza a porcentagem das lojas que estiverem ativas para o valor igual entre elas
 		 */
		UPDATE AD_PRODUTOLOJA 
		SET PESTTLOJA = @PORCENTAGEM 
		WHERE CODPROD = @CODPROD 
		AND ATIVO = 'S';
		
		/*
		 *	Atualiza para 0 a porcentagem das lojas que não estão ativas
		 */

		UPDATE AD_PRODUTOLOJA 
		SET PESTTLOJA = 0 
		WHERE CODPROD = @CODPROD 
		AND ATIVO = 'N';
	END
	
	/*
	 * Se não tiver disponível pelo menos 1 para cada loja ativa e o saldo também não for 0
	 */

	ELSE
	BEGIN

		/*
		 * Atualiza todas as lojas para 0 de porcentagem
		 */
		UPDATE AD_PRODUTOLOJA 
		SET PESTTLOJA = 0 
		WHERE CODPROD = @CODPROD;
		
		/*
		 * Verifica se a loja prioritária estava ativa, se estiver informa que ela irá receber a totalidade
		 */
		IF EXISTS(
			SELECT 1 
			FROM AD_PRODUTOLOJA WITH (NOLOCK)
			WHERE CODPROD = @CODPROD 
			AND ATIVO = 'S' 
			AND CODLOJA = @CODLOJAPRIO)
			
			SET @CODLOJATOTALIDADE = @CODLOJAPRIO;

		/*
		 * Se a loja prioritária não estiver ativa, e ela também não for a loja 1 mas a loja 1 estiver ativa, então ela irá receber a totalidade
		 */

		ELSE IF @CODLOJAPRIO != 1 
		AND EXISTS(
			SELECT 1 
			FROM AD_PRODUTOLOJA WITH (NOLOCK) 
			WHERE CODPROD = @CODPROD 
			AND ATIVO = 'S' 
			AND CODLOJA = 1)
			
			SET @CODLOJATOTALIDADE = 1;

		/*
		 * Caso nem a loja prioritária e nem a loja 1 estiverem ativas, então pega a loja com o menor código que estiver ativo para disponibilizar 
		 * a totalidade dos itens.
		 */
		ELSE 
			SELECT @CODLOJATOTALIDADE = MIN(CODLOJA) 
			FROM AD_PRODUTOLOJA WITH (NOLOCK) 
			WHERE CODPROD = @CODPROD 
			AND ATIVO = 'S';
		/*
		 * Atualiza para 100% o estoque para a loja que irá receber a totalidade, neste caso, a quantidade disponível
		 * para essa loja será a quantidade disponível em estoque para este produto, que também será algo ENTRE 1 e a 
		 * quantidade de lojas ativas, menos um.
		 */
		UPDATE AD_PRODUTOLOJA 
		SET PESTTLOJA = 100 
		WHERE CODPROD = @CODPROD 
		AND CODLOJA = @CODLOJATOTALIDADE;
	END

	/*
	 * Se os canais de vendas foram atualizados também, atualiza na TGFPRO a porcentagem para o WMW Vendas (Loja 0)
	 */
		
	IF UPDATE(ALTLOJA)
		UPDATE P 
		SET P.AD_PESTTVENDA = L.PESTTLOJA, P.AD_UTITVENDA = L.ATIVO
		FROM TGFPRO AS P WITH (NOLOCK)
		INNER JOIN AD_PRODUTOLOJA AS L
		ON L.CODPROD = P.CODPROD
		WHERE L.CODLOJA = 0 
		AND L.CODPROD = @CODPROD;
END