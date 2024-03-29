USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_AD_MULTILOJA_FORCA_ENVIO_VTEX]    Script Date: 14/06/2018 12:33:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2017-09-06
	Description:	Força o envio de um produto (atualização completa - catálogo + estoque + preço) para a VTEX, marcando
					os campos ALT* e DTALTER na tabela AD_MULTILOJA

	Author:			Guilherme Branco Stracini
	Change date:	2018-06-14
	Description:	Marca o campo Prioridade da tela como 1 - Alta, dando preferência a este produto na exportação!

	============================================= */
ALTER PROCEDURE [sankhya].[STP_AD_MULTILOJA_FORCA_ENVIO_VTEX] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE
       @FIELD_CODPROD INT,
       @I INT
BEGIN

       -- Os valores informados pelo formulário de parâmetros, podem ser obtidos com as funções:
       --     ACT_INT_PARAM
       --     ACT_DEC_PARAM
       --     ACT_TXT_PARAM
       --     ACT_DTA_PARAM
       -- Estas funções recebem 2 argumentos:
       --     ID DA SESSÃO - Identificador da execução (Obtido através de P_IDSESSAO))
       --     NOME DO PARAMETRO - Determina qual parametro deve se deseja obter.


       SET @I = 1 -- A variável "I" representa o registro corrente.
       WHILE @I <= @P_QTDLINHAS -- Este loop permite obter o valor de campos dos registros envolvidos na execução.
       BEGIN
           SET @FIELD_CODPROD = SANKHYA.ACT_INT_FIELD(@P_IDSESSAO, @I, 'CODPROD')
		   
		   UPDATE SANKHYA.AD_MULTILOJA
		   SET ALTESTOQUE = 'S', ALTLOJA = 'S', ALTPRECO = 'S', ALTPRODUTO = 'S', DTMODIF = GETDATE(), PRIORIDADE = '1'
		   WHERE CODPROD = @FIELD_CODPROD;

           SET @I = @I + 1
       END

	   SET @P_MENSAGEM = 'Em breve os produtos selecionados serão enviados para a VTEX.';

END
