USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_TGFPRO_AD_MULTILOJA]    Script Date: 03/10/2018 21:10:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2013-09-27
	Description:	Insere um novo produto na tabela AD_MULTILOJA assim que ele for cadastrado na TGFPRO.
	
	Author:			Guilherme Branco Stracini
	Create date:	2016-09-30
	Description:	Insere a loja príoritária 1 (Vitrine do Artesanato) como padrão para novos produtos.

	Author:			Guilherme Branco Stracini
	Change date:	2017-04-04
	Description:	Insere a marca 2000032 (Integração) como padrão para novos produtos.

	Author:			Guilherme Branco Stracini
	Change date:	2017-04-05
	Description:	Tenta obter a marca da AD_MARCASVTEX de acordo com o campo TGFPRO->MARCA, 
					se localizar usa esse, se não localizar usa marca Integração.
					Não atualiza mais o campo COMPLEMENTO na AD_MULTILOJA, o campo foi removido 
					e agora é um campo calculado (COMPLDESC) que busca da PRO, pra evitar o UPDATE.

	Author:			Rodrigo Lacalendola
	Change date:	2017-09-04
	Description:	Insere na tela de Logs de Alterações de Produtos VTEX

	Author:			Guilherme Branco Stracini
	Change date:	2018-06-14
	Description:	Cadastra o produto na tela Multiloja/Marketplace com a prioridade Normal

	Author:			Guilherme Branco Stracini
	Change date:	2018-09-13
	Description:	Cadastra o campo DTCADASTRO na tela Multiloja/Marketplace como a data atual

	Author:			Guilherme Branco Stracini
	Change date:	2018-10-03
	Description:	Preenche o campo CODRELACIONAMENTO com o valor 0
	
	=============================================*/
ALTER TRIGGER [sankhya].[TRG_INC_TGFPRO_AD_MULTILOJA] 
   ON  [sankhya].[TGFPRO] 
   AFTER INSERT
AS 
DECLARE
@CODMARCA INT
BEGIN
	SET NOCOUNT ON;

	/*
	 * Verifica se existe alguma marca na tabela AD_MARCASVTEX com o mesmo nome da marca na columa Marca da TGFPRO
	 */
	
	SELECT @CODMARCA = M.CODMARCA
	FROM INSERTED AS I 
	INNER JOIN AD_MARCASVTEX AS M WITH (NOLOCK)
	ON M.NOME = I.MARCA;
	
	/*
	 * Se a marca for nula, porque não localizou nenhuma com o mesmo nome
	 * Configura que o código da marca é 2000032 (Integração).
	 */
	IF @CODMARCA IS NULL
		SET @CODMARCA = 2000032;

	/*
	 * Faz o insert na AD_MULTILOJA com os dados do novo produto
	 */
	INSERT INTO AD_MULTILOJA 
	(CODPROD, CODLOJAPRIO, CODMARCA, DTMODIF, DTINTEGRACAO, DTSINCRONIZACAO, ALTPRODUTO, ALTLOJA, ALTPRECO, ALTESTOQUE, PRIORIDADE, DTCADASTRO, CODRELACIONAMENTO)
	SELECT CODPROD, 1, @CODMARCA,  DTALTER, DTALTER, DTALTER, 'S', 'N', 'N', 'N', '0', GETDATE(), 0 FROM INSERTED;


	/*
	 * Insere na tela de Logs de Alterações de Produtos VTEX 
	 */
	INSERT INTO AD_LOGALTERACOESVTEX (CODPROD, DTALTER, OCORRENCIA)
	SELECT CODPROD, GETDATE(), 'Produto inserido' FROM INSERTED


END
